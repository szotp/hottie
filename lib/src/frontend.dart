#!/usr/bin/env dart

import 'dart:async';

import 'package:hottie/src/daemon.dart';
import 'package:hottie/src/script_change.dart';
import 'package:hottie/src/utils/logger.dart';
import 'package:hottie/src/watch.dart';

class HottieFrontendNew {
  late final FlutterDaemon daemon;
  late final ScriptChangeChecker _scriptChecker;

  Future<void> run() async {
    daemon = FlutterDaemon();
    await daemon.start(path: 'test/main_hottie_dart_only.dart');

    _scriptChecker = ScriptChangeChecker(daemon.vmService);

    callHottieTest(RelativePaths({'file_2_test.dart'})).withLogging(); // only for testing

    watchDartFiles().forEach(_onFilesChanged).withLogging();

    await daemon.waitForExit();
  }

  /// Executes when any dart file changes.
  /// Causes hot reload, which eventually leads to _onIsolateReload being called.
  Future<void> _onFilesChanged(String changedFile) async {
    logger.fine('_onFilesChanged: $changedFile');
    await daemon.callHotReload();

    final paths = await _scriptChecker.checkLibraries(daemon.isolateId);

    await callHottieTest(paths);
  }

  Future<void> callHottieTest(RelativePaths paths) async {
    logger.info('Testing: ${paths.paths.join(", ")}');
    final r = await daemon.callServiceExtension('ext.hottie.test', {
      'paths': paths.encode(),
    });
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
