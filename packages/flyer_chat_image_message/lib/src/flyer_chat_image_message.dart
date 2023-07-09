import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:provider/provider.dart';
import 'package:thumbhash/thumbhash.dart' hide Image;

import 'get_thumbhash_bytes.dart';
import 'preload_image_provider.dart';

class FlyerChatImageMessage extends StatefulWidget {
  final ImageMessage message;

  const FlyerChatImageMessage({
    super.key,
    required this.message,
  });

  @override
  FlyerChatImageMessageState createState() => FlyerChatImageMessageState();
}

class FlyerChatImageMessageState extends State<FlyerChatImageMessage>
    with TickerProviderStateMixin {
  double? _aspectRatio;
  late final AnimationController _opacityAnimationController;
  late final Animation<double> _opacityAnimation;
  late final AnimationController _progressAnimationController;
  late final Animation<double> _progressAnimation;
  ImageProvider? _thumbHashProvider;
  ImageProvider? _imageProvider;
  StreamSubscription<DownloadProgress>? _downloadSubscription;
  Uint8List? _thumbHashBytes;

  @override
  void initState() {
    super.initState();
    final mediaCache = Provider.of<MediaCache>(context, listen: false);
    final mediaLoader = Provider.of<MediaLoader>(context, listen: false);
    final storage = Provider.of<Storage>(context, listen: false);

    if (widget.message.width != null && widget.message.height != null) {
      _aspectRatio = widget.message.width! / widget.message.height!;
    } else if (widget.message.thumbhash?.isNotEmpty == true) {
      _thumbHashBytes = getThumbHashBytes(widget.message.thumbhash!);
      _aspectRatio = thumbHashToApproximateAspectRatio(_thumbHashBytes!);
    }

    final fileNameBytes = utf8.encode(widget.message.source);
    final fileName = sha256.convert(fileNameBytes).toString();

    _opacityAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _opacityAnimationController,
        curve: Curves.fastOutSlowIn,
      ),
    );

    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _progressAnimationController,
        curve: Curves.fastOutSlowIn,
      ),
    );

    storage.get(fileName).then((value) {
      if (mounted) {
        if (value is Uint8List) {
          final provider = MemoryImage(value);
          _preloadThumbHash(provider);
        } else if (widget.message.thumbhash?.isNotEmpty == true) {
          _thumbHashBytes ??= getThumbHashBytes(widget.message.thumbhash!);
          final rgbaImage = thumbHashToRGBA(_thumbHashBytes!);
          final bmp = rgbaToBmp(rgbaImage);
          final provider = MemoryImage(bmp);
          _preloadThumbHash(provider);
          storage.set(fileName, bmp);
        }
      }
    });

    mediaCache.get(fileName).then((value) {
      if (mounted) {
        if (value != null) {
          final provider = MemoryImage(value);
          _preloadImage(provider);
        } else {
          final stream = mediaLoader.download(widget.message.source);

          _downloadSubscription = stream.listen(
            (downloaded) {
              if (mounted) {
                _progressAnimationController.value = downloaded.progress;

                if (downloaded.file != null) {
                  downloaded.file!.readAsBytes().then(
                    (bytes) {
                      if (mounted) {
                        final provider = MemoryImage(bytes);
                        _preloadImage(provider);
                        mediaCache.set(fileName, bytes);
                      }
                    },
                  );
                }
              }
            },
            cancelOnError: true,
          );
        }
      }
    });
  }

  void _preloadThumbHash(ImageProvider provider) {
    preloadImageProvider(provider).then((_) {
      if (!mounted || _imageProvider != null) return;
      setState(() {
        _thumbHashProvider = provider;
      });
    });
  }

  void _preloadImage(ImageProvider provider) {
    preloadImageProvider(provider).then((dimensions) {
      if (!mounted) return;

      if (widget.message.width != dimensions.$1 ||
          widget.message.height != dimensions.$2) {
        _aspectRatio = dimensions.$1 / dimensions.$2;
        _imageProvider = provider;

        final chatController =
            Provider.of<ChatController>(context, listen: false);

        chatController.update(
          widget.message,
          widget.message.copyWith(
            width: dimensions.$1,
            height: dimensions.$2,
          ),
        );
      } else {
        setState(() {
          _imageProvider = provider;
        });
      }

      _opacityAnimationController.forward();
    });
  }

  @override
  Future<void> dispose() async {
    try {
      _opacityAnimationController.dispose();
    } catch (e) {
      debugPrint('Error disposing opacity animation controller: $e');
    }
    try {
      _progressAnimationController.dispose();
    } catch (e) {
      debugPrint('Error disposing progress animation controller: $e');
    }
    try {
      // Wrapped in Future.delayed as per this issue: https://github.com/flutter/flutter/issues/64935
      Future.delayed(Duration.zero, () async {
        await _downloadSubscription?.cancel();
      });
    } catch (e) {
      debugPrint('Error canceling download subscription: $e');
    }
    try {
      Future.delayed(Duration.zero, () async {
        await _imageProvider?.evict();
      });
    } catch (e) {
      debugPrint('Error evicting image provider: $e');
    }
    try {
      Future.delayed(Duration.zero, () async {
        await _thumbHashProvider?.evict();
      });
    } catch (e) {
      debugPrint('Error evicting thumb hash provider: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 300, minWidth: 170),
        child: AspectRatio(
          aspectRatio: _aspectRatio ?? 1,
          child: Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              if (_thumbHashProvider != null)
                Image(
                  image: _thumbHashProvider!,
                  fit: BoxFit.fill,
                ),
              if (_imageProvider == null)
                Center(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (_, __) {
                        final animationNotRunning = _progressAnimation.status ==
                                AnimationStatus.completed ||
                            _progressAnimation.status ==
                                AnimationStatus.dismissed;

                        return animationNotRunning
                            ? const SizedBox()
                            : CircularProgressIndicator(
                                backgroundColor: Colors.white.withOpacity(0.1),
                                color: Colors.white,
                                value: _progressAnimation.value,
                              );
                      },
                    ),
                  ),
                ),
              if (_imageProvider != null)
                FadeTransition(
                  opacity: _opacityAnimation,
                  child: Image(
                    image: _imageProvider!,
                    fit: BoxFit.fill,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
