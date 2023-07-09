import 'dart:typed_data';

import 'base_media_cache.dart';

class MediaCache extends BaseMediaCache {
  @override
  Future<void> set(String key, Uint8List value) {
    throw UnimplementedError(
      'Cache is not available in your current platform.',
    );
  }

  @override
  Future<void> update(String key, Uint8List value) {
    throw UnimplementedError(
      'Cache is not available in your current platform.',
    );
  }

  @override
  Future<Uint8List?> get(String key) {
    throw UnimplementedError(
      'Cache is not available in your current platform.',
    );
  }

  @override
  void dispose() {
    throw UnimplementedError(
      'Cache is not available in your current platform.',
    );
  }
}
