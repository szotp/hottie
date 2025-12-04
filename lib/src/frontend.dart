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

    await daemon.callHotReload();

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

    final result = await daemon.vmService.callServiceExtension('ext.hottie.test', isolateId: daemon.isolateId);
    logger.i('Call extension: $result');
  }
}
