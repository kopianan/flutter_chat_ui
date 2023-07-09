import 'package:cross_file/cross_file.dart';

class DownloadProgress {
  /// A value between 0 and 1 representing the progress of the download.
  final double progress;
  final XFile? file;

  DownloadProgress(this.progress, {this.file});
}
