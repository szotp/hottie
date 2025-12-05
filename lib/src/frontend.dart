#!/usr/bin/env dart

import 'dart:async';

import 'package:hottie/src/daemon.dart';
import 'package:hottie/src/utils/logger.dart';
import 'package:hottie/src/watch.dart';

class HottieFrontendNew {
  late final FlutterDaemon daemon;

  Future<void> run() async {
    daemon = FlutterDaemon();
    await daemon.start(path: 'test/main_hottie_dart_only.dart');

    await _onFilesChanged('x');

    return watchDartFiles().forEach(_onFilesChanged);
  }

  /// Executes when any dart file changes.
  /// Causes hot reload, which eventually leads to _onIsolateReload being called.
  Future<void> _onFilesChanged(String changedFile) async {
    logger.info('_onFilesChanged: $changedFile');
    await daemon.callHotReload();
    await callHottieTest();
  }

  Future<void> callHottieTest() async {
    final r = await daemon.callServiceExtension('ext.hottie.test', {});
    logger.info(r.result);

    await daemon.callHotReload(fullRestart: true);
    daemon.onLine = null;
  }
}
