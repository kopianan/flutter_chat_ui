import 'download_progress.dart';

abstract class MediaLoader {
  Stream<DownloadProgress> download(String url);

  void dispose();
}
