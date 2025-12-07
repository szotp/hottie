import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate' as isolate;

import 'package:hottie/src/script_change.dart';
import 'package:hottie/src/utils/logger.dart';
import 'package:vm_service/vm_service.dart';

/// Starts watching Dart files for changes.
/// Returns a stream that emits the path of changed Dart files.
Stream<String> watchDartFiles([List<String> directories = const ['lib', 'test']]) {
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

/// Gets the package directory from Platform.script.
/// Only works in debug mode when running with Observatory/VM service enabled.
String? _getPackageDirectory() {
  final scriptUri = Platform.script;

  // In debug mode, Platform.script typically looks like:
  // file:///path/to/package/bin/script.dart or
  // file:///path/to/package/lib/src/file.dart

  if (scriptUri.scheme != 'file') {
    return null; // Not a file URI
  }

  final scriptPath = scriptUri.toFilePath();
  final file = File(scriptPath);

  // Traverse up the directory tree to find the package root
  // (directory containing pubspec.yaml)
  var dir = file.parent;
  while (dir.path != dir.parent.path) {
    final pubspec = File('${dir.path}/pubspec.yaml');
    if (pubspec.existsSync()) {
      return dir.path;
    }
    dir = dir.parent;
  }

  return null; // Could not find package root
}

Future<void> hotReloadAutomatically([Stream<void> Function()? onReloaded]) async {
  StreamSubscription<void>? sub;

  sub = onReloaded?.call().listen(null);
  final vm = await vmServiceConnect();

  if (vm == null) {
    return; // debugging not available
  }

  final packageDir = _getPackageDirectory();
  if (packageDir == null) {
    return;
  }

  final isolateId = Service.getIsolateId(isolate.Isolate.current)!;

  watchDartFiles(['$packageDir/bin', '$packageDir/lib']).forEach((_) async {
    final reloaded = await vm.reloadSources(isolateId);
    logger.info('Reloaded: ${reloaded.success}');
  }).withLogging();

  vm.onIsolateEvent.forEach((event) {
    if (event.kind == EventKind.kIsolateReload) {
      sub?.cancel().ignore();
      sub = onReloaded?.call().listen(null);
    }
  }).withLogging();

  vm.streamListen(EventStreams.kIsolate).withLogging();
}
