import 'dart:convert';
import 'dart:typed_data';

Uint8List getThumbHashBytes(String thumbHash) {
  return base64Decode(base64.normalize(thumbHash));
}
