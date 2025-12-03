import 'dart:async';
import 'dart:io';

/// Starts watching Dart files for changes.
/// Returns a stream that emits the path of changed Dart files.
Stream<String> watchDartFiles() {
  final lib = Directory('lib');
  final test = Directory('test');

  final controller = StreamController<String>();

  void handleEvent(FileSystemEvent event) {
    if (event.path.endsWith('.dart') && (event is FileSystemModifyEvent || event is FileSystemCreateEvent)) {
      controller.add(event.path);
    }
  }

  final libWatch = lib.watch(recursive: true).listen(handleEvent);
  final testWatch = test.watch(recursive: true).listen(handleEvent);

  controller.onCancel = () {
    libWatch.cancel().ignore();
    testWatch.cancel().ignore();
  };

  return controller.stream;
}
