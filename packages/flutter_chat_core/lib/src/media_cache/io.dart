import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'base_media_cache.dart';

class MediaCache extends BaseMediaCache {
  @override
  Future<void> set(String key, Uint8List value) async {
    final cache = await getApplicationCacheDirectory();
    final media = Directory('${cache.path}/flyer-chat-media');

    if (!await media.exists()) {
      await media.create(recursive: true);
    }

    final path = '${media.path}/$key';
    final file = File(path);
    await file.writeAsBytes(value);
  }

  @override
  Future<void> update(String key, Uint8List value) async {
    final cache = await getApplicationCacheDirectory();
    final media = Directory('${cache.path}/flyer-chat-media');

    if (!await media.exists()) {
      await media.create(recursive: true);
    }

    final path = '${media.path}/$key';
    final file = File(path);
    await file.writeAsBytes(value);
  }

  @override
  Future<Uint8List?> get(String key) async {
    try {
      final cache = await getApplicationCacheDirectory();
      final file = File('${cache.path}/flyer-chat-media/$key');

      if (await file.exists()) {
        return await file.readAsBytes();
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {}
}
