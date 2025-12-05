import 'dart:async';
import 'dart:io';

import 'package:hottie/src/utils/logger.dart';

/// Starts watching Dart files for changes.
/// Returns a stream that emits the path of changed Dart files.
Stream<String> watchDartFiles() {
  final directories = ['lib', 'test', '../lib'];
  logger.fine('Watching: ${Directory.current.path}: $directories');
  final controller = StreamController<String>();

  void handleEvent(FileSystemEvent event) {
    if (event.path.endsWith('.dart') && (event is FileSystemModifyEvent || event is FileSystemCreateEvent)) {
      controller.add(event.path);
    }
  }

  final listeners = directories.map(Directory.new).map((x) => x.watch(recursive: true).listen(handleEvent)).toList();

  controller.onCancel = () async {
    logger.info('cancel');
    await Future.wait(listeners.map((x) => x.cancel()));
  };

  return controller.stream;
}
