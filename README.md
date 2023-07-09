## Create a new example or package

### To create a new example:

1. Go to examples folder

```bash
cd examples
```

2. Run the following command:

```bash
flutter create example_name --org flyer.chat
```

3. Go to the root folder

```bash
cd ..
```

4. Run melos bootstrap:

```bash
melos bs
```

5. Replace `analysis_options.yaml` content with the following:

```bash
include: ../../analysis_options.yaml

```

### To create a new package:

1. Go to packages folder

```bash
cd packages
```

2. Run the following command:

```bash
flutter create package_name --template=package
```

3. Go to the root folder

```bash
cd ..
```

4. Run melos bootstrap:

```bash
melos bs
```

5. Replace `analysis_options.yaml` content with the following:

```bash
include: ../../analysis_options.yaml

```

6. Make sure to follow other packages structure. Minimum required files are:

```
.dart_tool/
lib/
  src/
    code.dart
  package_name.dart
analysis_options.yaml
CHANGELOG.md
LICENSE
melos_package_name.iml
pubspec_overrides.yaml
pubspec.lock
pubspec.yaml
README.md
```

Remove all other files if needed and update `pubspec.yaml` similar to other packages.

Remember to run `melos bs` again after you finished all configs and changed `pubspec.yaml` file.

## Tests

To run tests for a specific package:

```bash
melos test:selective
```

To run all tests:

```bash
melos test
```

To generate coverage for a specific package:

```bash
melos coverage:selective
```

To generate coverage for all packages:

```bash
melos coverage
```

## Misc

Get dependencies for all packages:

```bash
melos bs
```

Clean all packages:

```bash
melos clean
```

Build types (flutter_chat_types):

```bash
melos build
```

Additional:

```bash
melos analyze
melos format
melos fix
```

## Dependencies that require Dart >=3.2.0 and Flutter >=3.16.0

- cross_file (latest working for Dart 3.0.0 and Flutter 3.10.0 is 0.3.3+7)
- mime (latest working for Dart 3.0.0 and Flutter 3.10.0 is 1.0.4)
- web_socket_channel (latest working for Dart 3.0.0 and Flutter 3.10.0 is 2.4.0)

## Todo next

- When I add a message previous message will be rebuilt with the new ID
- When I remove messages above image messages, all image messages below will be rebuilt and animate

## Gemini suggestions

### media_cache

- Make your error handling more granular. Instead of general Exception catches, try to catch specific errors (e.g., IdbFactoryNotSupportedException, FileSystemException) and provide more informative error messages or actions.
- File Management: Consider how you'll handle cache size limits or file cleanup.
  - IndexedDB: Browsers might have quota limits. You could implement a cleanup strategy when approaching the limit.
  - File System: You might want a strategy to purge old and unused cache files periodically.

### media_loader

- Similar to our discussion on the media cache, include more specific error handling types in the catch block of `_downloadAndSave`.
- Cancellation: Consider providing a way to cancel in-progress downloads. This could involve:
  - Adding a cancel() method to your MediaLoader interface.
  - Exposing a way to cancel the underlying Dio request.
- If you frequently download large files, the broadcast StreamController could hold data in memory for multiple listeners. A single-subscription StreamController might be more memory-efficient if you don't need multiple subscribers to the progress stream.

### storage

- Instead of returning null from get if a key doesn't exist, you could create a custom exception like KeyNotFoundException for more explicit error handling.

### theme

- Type Safety and Clarity: While the Object trick lets you store null values for flexibility, let's make this type-safe and readable. You can use nullable types and a custom class to track value sources:

```dart
class ThemeValue<T> { // Represents a theme value, either set or unset
  final T? value;
  final bool isSetByUser;

  ThemeValue.user(this.value) : isSetByUser = true; // User-provided value
  ThemeValue.unset() : value = null, isSetByUser = false; // Unset
}

class ChatTheme extends Equatable {
  final ThemeValue<Color> backgroundColor;
  final ThemeValue<String> fontName;

  // ... rest of your constructors and logic
}
```

- Builder Pattern: Instead of multiple parameters in copyWith and merge, consider a cleaner builder-like pattern:

```dart
ChatTheme copyWith({
  ChatThemeBuilder? builder,
}) {
  final newBuilder = ChatThemeBuilder._from(this);
  builder?.call(newBuilder);
  return newBuilder.build();
}

class ChatThemeBuilder {
  ThemeValue<Color> backgroundColor;
  ThemeValue<String> fontName;

  ChatThemeBuilder._from(ChatTheme theme)
    : backgroundColor = theme.backgroundColor,
      fontName = theme.fontName;

  void setBackgroundColor(Color color) =>
    backgroundColor = ThemeValue.user(color);

  void setFontName(String name) =>
    fontName = ThemeValue.user(name);

  ChatTheme build() => ChatTheme(
     backgroundColor: backgroundColor,
     fontName: fontName
  );
}
```

Usage:

```dart
// Partial customization
final customTheme = ChatTheme.defaultTheme(Brightness.dark).copyWith(
  builder: (builder) {
    builder.setBackgroundColor(Colors.blue);
  }
);
```
