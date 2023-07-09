import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:provider/provider.dart';
import 'chat_animated_list.dart';
import 'chat_message.dart';
import 'utils/typedefs.dart';

class Chat extends StatefulWidget {
  final String userId;
  final ChatController chatController;
  final ChatTheme? theme;
  final MediaCache? mediaCache;
  final MediaLoader? mediaLoader;
  final Storage? storage;
  final OnMessageTapCallback? onMessageTap;

  const Chat({
    super.key,
    required this.userId,
    required this.chatController,
    this.theme,
    this.mediaCache,
    this.mediaLoader,
    this.storage,
    this.onMessageTap,
  });

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> with WidgetsBindingObserver {
  late ChatTheme _theme;
  late MediaLoader _mediaLoader;
  late Storage _storage;
  late MediaCache _mediaCache;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateTheme();
    _mediaLoader = widget.mediaLoader ?? DioMediaLoader();
    _storage = widget.storage ?? InMemoryStorage();
    _mediaCache = widget.mediaCache ?? MediaCache();
  }

  @override
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    // Only try to dispose media loader if it's not provided, since
    // users might want to keep downloading media even after the chat
    // is disposed.
    if (widget.mediaLoader == null) {
      try {
        _mediaLoader.dispose();
      } catch (e) {
        debugPrint('Error disposing media loader: $e');
      }
    }
    try {
      // Wrapped in Future.delayed as per this issue: https://github.com/flutter/flutter/issues/64935
      Future.delayed(Duration.zero, () async {
        await _storage.dispose();
      });
    } catch (e) {
      debugPrint('Error disposing storage: $e');
    }
    try {
      _mediaCache.dispose();
    } catch (e) {
      debugPrint('Error disposing media cache: $e');
    }
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    setState(_updateTheme);
  }

  @override
  void didUpdateWidget(covariant Chat oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.theme != widget.theme) {
      _theme = _theme.merge(widget.theme);
    }
  }

  void _updateTheme() {
    _theme =
        ChatTheme.defaultTheme(PlatformDispatcher.instance.platformBrightness)
            .merge(widget.theme);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: widget.userId),
        Provider.value(value: widget.chatController),
        Provider.value(value: _theme),
        Provider.value(value: _mediaLoader),
        Provider.value(value: _storage),
        Provider.value(value: _mediaCache),
      ],
      child: ChatWidget(
        onMessageTap: widget.onMessageTap,
      ),
    );
  }
}

class ChatWidget extends StatelessWidget {
  final OnMessageTapCallback? onMessageTap;

  const ChatWidget({
    super.key,
    this.onMessageTap,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        context.select((ChatTheme theme) => theme.backgroundColor);

    return Container(
      color: backgroundColor,
      child: ChatAnimatedList(
        itemBuilder: (_, animation, message, {bool? isRemoved}) => ChatMessage(
          key: ValueKey(message.id),
          animation: animation,
          message: message,
          onMessageTap: onMessageTap,
          isRemoved: isRemoved,
        ),
      ),
    );
  }
}
