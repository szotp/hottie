#!/usr/bin/env dart

import 'dart:async';
import 'dart:io';

import 'package:hottie/src/daemon.dart';
import 'package:hottie/src/utils/logger.dart';
import 'package:hottie/src/watch.dart';

class HottieFrontendNew {
  late final FlutterDaemon daemon;

  Future<void> run() async {
    daemon = FlutterDaemon();
    await daemon.start(path: 'test/main_hottie_dart_only.dart');

    _onFilesChanged('x').withLogging(); // only for testing

    watchDartFiles().forEach(_onFilesChanged).withLogging();

    await stdin.map((x) => x[0] == 'q'.codeUnits[0]).first;
  }

  /// Executes when any dart file changes.
  /// Causes hot reload, which eventually leads to _onIsolateReload being called.
  Future<void> _onFilesChanged(String changedFile) async {
    logger.fine('_onFilesChanged: $changedFile');
    await daemon.callHotReload();
    await callHottieTest();
  }

  Future<void> callHottieTest() async {
    final r = await daemon.callServiceExtension('ext.hottie.test', {});
    final passed = r.result['passed'] as int;
    final failed = r.result['failed'] as int;
    final skipped = r.result['skipped'] as int;

    if (failed == 0) {
      if (skipped > 0) {
        logger.info('Tests passed: $passed ($skipped skipped)');
      } else {
        logger.info('Tests passed: $passed');
      }
    }

    await daemon.callHotReload(fullRestart: true);
    daemon.onLine = null;
  }
}
