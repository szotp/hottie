import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate' as isolate;

import 'package:hottie/src/script_change.dart';
import 'package:hottie/src/utils/logger.dart';
import 'package:vm_service/vm_service.dart';

/// Starts watching Dart files for changes.
/// Returns a stream that emits the path of changed Dart files.
Stream<String> watchDartFiles([List<String> directories = const ['lib', 'test', '../lib']]) {
  logger.fine('Watching: ${Directory.current.path}: $directories');
  final controller = StreamController<String>();

  void handleEvent(FileSystemEvent event) {
    logger.fine(event);
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

Future<void> hotReloadAutomatically(Stream<void> Function() onReloaded) async {
  StreamSubscription<void>? sub;

  sub = onReloaded().listen(null);
  final vm = await vmServiceConnect();

  if (vm == null) {
    return; // debugging not available
  }

  final isolateId = Service.getIsolateId(isolate.Isolate.current)!;

  watchDartFiles(['bin']).forEach((_) async {
    final reloaded = await vm.reloadSources(isolateId);
    logger.info('Reloaded: ${reloaded.success}');
  }).withLogging();

  vm.onIsolateEvent.forEach((event) {
    if (event.kind == EventKind.kIsolateReload) {
      sub?.cancel().ignore();
      sub = onReloaded().listen(null);
    }
  }).withLogging();

  vm.streamListen(EventStreams.kIsolate).withLogging();
}
