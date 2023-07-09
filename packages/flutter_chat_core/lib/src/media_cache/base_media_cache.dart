import 'dart:typed_data';

abstract class BaseMediaCache {
  Future<void> set(String key, Uint8List value);
  Future<void> update(String key, Uint8List value);
  Future<Uint8List?> get(String key);

  void dispose();
}
