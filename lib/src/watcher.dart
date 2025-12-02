import 'dart:async';
import 'dart:io';

import 'package:hottie/src/utils/logger.dart';

/// Starts watching Dart files for changes.
/// Returns a stream that emits the path of changed Dart files.
Stream<String> watchDartFiles() {
  logger('Watching ${Directory.current.path}');
  final lib = Directory('lib');
  final test = Directory('test');

  final controller = StreamController<String>();

  void handleEvent(FileSystemEvent event) {
    if (_shouldReload(event)) {
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

bool _shouldReload(FileSystemEvent event) {
  switch (event) {
    case FileSystemModifyEvent():
      break;
    default:
      return false;
  }

  return event.path.endsWith('.dart');
}
