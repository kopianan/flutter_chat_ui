import 'dart:async';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';
import 'package:mime/mime.dart';

import 'download_progress.dart';
import 'media_loader.dart';

class DioMediaLoader extends MediaLoader {
  late Dio _dio;
  final Map<String, StreamController<DownloadProgress>> _activeDownloads = {};

  DioMediaLoader([BaseOptions? options]) {
    _dio = Dio(options);
  }

  Future<void> _downloadAndSave(
    String url,
    StreamController<DownloadProgress> controller,
  ) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.bytes,
        ),
        onReceiveProgress: (count, total) {
          if (total <= 0) return;
          final progress = count / total;
          controller.add(DownloadProgress(progress));
        },
      );

      if (response.statusCode != 200) {
        throw DioException.badResponse(
          statusCode: response.statusCode ?? -1,
          requestOptions: response.requestOptions,
          response: response,
        );
      }

      final bytes = response.data as Uint8List;

      final contentType = response.headers.value(Headers.contentTypeHeader);
      final mimeType = contentType ??
          lookupMimeType(url, headerBytes: bytes.take(16).toList());

      final file = XFile.fromData(
        bytes,
        mimeType: mimeType,
        length: bytes.length,
        lastModified: DateTime.now(),
      );
      controller.add(DownloadProgress(1, file: file));
    } catch (error) {
      controller.addError(error);
    } finally {
      await controller.close();
      _activeDownloads.remove(url);
    }
  }

  @override
  Stream<DownloadProgress> download(String url) {
    if (_activeDownloads.containsKey(url)) {
      return _activeDownloads[url]!.stream;
    }

    final controller = StreamController<DownloadProgress>.broadcast();
    _activeDownloads[url] = controller;

    _downloadAndSave(url, controller);

    return controller.stream;
  }

  @override
  void dispose() {
    _dio.close(force: true);
  }
}
