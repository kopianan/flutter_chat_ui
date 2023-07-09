// Method signature for _loadAsync decode callbacks.
import 'dart:async';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

typedef _SimpleDecoderCallback = Future<ui.Codec> Function(
  ui.ImmutableBuffer buffer,
);

class CustomNetworkImage extends ImageProvider<NetworkImage>
    implements NetworkImage {
  const CustomNetworkImage(this.url, {this.scale = 1.0, this.headers});

  @override
  final String url;
  @override
  final double scale;
  @override
  final Map<String, String>? headers;

  @override
  Future<NetworkImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<NetworkImage>(this);
  }

  static Dio get _dio => Dio();

  @override
  ImageStreamCompleter loadImage(
    NetworkImage key,
    ImageDecoderCallback decode,
  ) {
    // Ownership of this controller is handed off to [_loadAsync]; it is that
    // method's responsibility to close the controller's stream when the image
    // has been loaded or an error is thrown.
    final chunkEvents = StreamController<ImageChunkEvent>();

    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, chunkEvents, decode: decode),
      chunkEvents: chunkEvents.stream,
      scale: key.scale,
      debugLabel: key.url,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<NetworkImage>('Image key', key),
      ],
    );
  }

  Future<ui.Codec> _loadAsync(
    NetworkImage key,
    StreamController<ImageChunkEvent> chunkEvents, {
    required _SimpleDecoderCallback decode,
  }) async {
    try {
      assert(key == this);

      final uri = Uri.parse(key.url);

      final response = await _dio.get(
        url,
        options: Options(
          headers: headers,
          responseType: ResponseType.bytes,
        ),
        onReceiveProgress: (cumulative, total) {
          chunkEvents.add(
            ImageChunkEvent(
              cumulativeBytesLoaded: cumulative,
              expectedTotalBytes: total <= 0 ? null : total,
            ),
          );
        },
      );

      if (response.statusCode != 200) {
        throw NetworkImageLoadException(
          statusCode: response.statusCode ?? -1,
          uri: uri,
        );
      }

      final bytes = response.data as Uint8List;

      if (bytes.lengthInBytes == 0) {
        throw Exception('NetworkImage is an empty file: ${key.url}');
      }

      return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
    } catch (e) {
      // Depending on where the exception was thrown, the image cache may not
      // have had a chance to track the key in the cache at all.
      // Schedule a microtask to give the cache a chance to add the key.
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
      rethrow;
    } finally {
      await chunkEvents.close();
    }
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is NetworkImage && other.url == url && other.scale == scale;
  }

  @override
  int get hashCode => Object.hash(url, scale);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'NetworkImage')}("$url", scale: ${scale.toStringAsFixed(1)})LOL';
}
