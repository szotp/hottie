#!/usr/bin/env dart

import 'dart:async';

import 'package:hottie/src/daemon.dart';
import 'package:hottie/src/utils/logger.dart';
import 'package:hottie/src/watch.dart';

class HottieFrontendNew {
  late final FlutterDaemon daemon;

  Future<void> run() async {
    daemon = FlutterDaemon();
    await daemon.start();

    await _onFilesChanged('x');

    return watchDartFiles().forEach(_onFilesChanged);
  }

  /// Executes when any dart file changes.
  /// Causes hot reload, which eventually leads to _onIsolateReload being called.
  Future<void> _onFilesChanged(String changedFile) async {
    logger.i('_onFilesChanged: $changedFile');
    await daemon.callHotReload();
    await callHottieTest();
  }

  Future<void> callHottieTest() async {
    logger.i('Call extension');

    // https://github.com/flutter/flutter/blob/master/packages/flutter_test/lib/src/test_compat.dart

    final onComplete = Completer<String>();
    daemon.onLine = (line) {
      if (line.endsWith('Some tests failed.') || line.endsWith('All tests passed!') || line.endsWith('All tests skipped.')) {
        onComplete.complete(line);
      }
    };
    await daemon.callServiceExtension('ext.hottie.test', {});

    final line = await onComplete.future;
    logger.i(line);

    await daemon.callHotReload(fullRestart: true);
    daemon.onLine = null;
  }
}
