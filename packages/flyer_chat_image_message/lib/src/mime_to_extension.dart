final Map<String, String> mimeToExtension = {
  'image/gif': '.gif',
  'image/jpeg': '.jpg',
  'image/jpg': '.jpg',
  'image/png': '.png',
  'image/tiff': '.tiff',
  'image/webp': '.webp',
};

// void _downloadImage() async {
//   try {
//     final response = await http.get(Uri.parse(widget.message.source));
//     final contentType = response.headers['content-type'];
//     final responseBytes = response.bodyBytes;
//     final mimeType = contentType ??
//         lookupMimeType(
//           widget.message.source,
//           headerBytes: responseBytes.take(16).toList(),
//         );
//     final extension = mimeToExtension[mimeType] ?? '';
//     final fileNameBytes = utf8.encode(widget.message.source);
//     final fileName = sha256.convert(fileNameBytes).toString();
//     final name = '$fileName$extension';
//     final cache = await getApplicationCacheDirectory();
//     final file = XFile.fromData(
//       response.bodyBytes,
//       mimeType: mimeType,
//       name: name,
//       length: responseBytes.lengthInBytes,
//     );
//     await file.saveTo('${cache.path}/$name');
//   } catch (e) {
//     // Handle error
//   }
// }
