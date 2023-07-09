import 'dart:async';

import 'package:flutter/widgets.dart';

typedef Dimensions = (double width, double height);

Future<Dimensions> preloadImageProvider(ImageProvider provider) {
  ImageStream? stream;
  final completer = Completer<Dimensions>();
  const config = ImageConfiguration.empty;

  final listener = ImageStreamListener(
    (image, synchronousCall) {
      completer.complete(
        (
          image.image.width.toDouble(),
          image.image.height.toDouble(),
        ),
      );
    },
    onError: (exception, stackTrace) {
      completer.completeError(exception, stackTrace);
    },
  );

  provider.obtainKey(config).then((key) {
    stream = provider.resolve(config);
    stream?.addListener(listener);
  }).catchError((error) {
    completer.completeError(error);
  });

  completer.future.whenComplete(() {
    stream?.removeListener(listener);
  });

  return completer.future;
}
