#!/usr/bin/env dart

import 'dart:async';

import 'package:hottie/src/daemon.dart';
import 'package:hottie/src/generate_main.dart';
import 'package:hottie/src/script_change.dart';
import 'package:hottie/src/utils/logger.dart';
import 'package:hottie/src/watch.dart';

class HottieFrontendNew {
  late final FlutterDaemon daemon;
  late final ScriptChangeChecker _scriptChecker;
  bool _isInitialized = false;
  String? isolateId;
  final Set<RelativePath> _failedTests = {};

  Future<void> run(List<String> args) async {
    final path = await generateMain(args);

    //logger.level = Level.ALL;
    daemon = FlutterDaemon();
    daemon.handlers['hottie.registered'] = _onHottieRegistered;
    daemon.handlers['hottie.fail'] = _onHottieFail;
    await daemon.start(path: path);

    _scriptChecker = ScriptChangeChecker(daemon.vmService);
    _isInitialized = true;

    callHottieTest(RelativePaths({'test/file_2_test.dart'})).withLogging(); // only for testing

    watchDartFiles().forEach(_onFilesChanged).withLogging();

    await daemon.waitForExit();
  }

  /// Executes when any dart file changes.
  /// Causes hot reload, which eventually leads to _onIsolateReload being called.
  Future<void> _onFilesChanged(String changedFile) async {
    logger.fine('_onFilesChanged: $changedFile');
    await daemon.callHotReload();

    final paths = await _scriptChecker.checkLibraries(isolateId!);

    if (paths.paths.isEmpty) {
      return;
    }

    await callHottieTest(paths);
  }

  void _onHottieRegistered(DaemonEvent event) {
    isolateId = event.params['isolateId'] as String;
    if (!_isInitialized) {
      return;
    }
    _scriptChecker.checkLibraries(isolateId!).withLogging();
  }

  void _onHottieFail(DaemonEvent event) {
    final stackTrace = StackTrace.fromString(event.params['stackTrace'] as String);
    final message = event.params['error'];
    final testName = event.params['name'];
    logger.warning('Test "$testName" failed\n$message', null, stackTrace);
  }

  Future<void> callHottieTest(RelativePaths paths) async {
    logger.info('Testing: ${paths.paths.join(", ")}');
    final r = await daemon.callServiceExtension('ext.hottie.test', {
      'paths': paths.encode(),
    });
    final passed = r.result['passed'] as int;
    final failed = (r.result['failed'] as List).toSet().cast<String>();

    for (final path in paths.paths) {
      if (failed.contains(path)) {
        _failedTests.add(path);
      } else {
        _failedTests.remove(path);
      }
    }

    if (failed.isEmpty) {
      final failedStrings = _failedTests.join(', ');

      if (_failedTests.isEmpty) {
        logger.info('Tests passed: $passed. All good!');
      } else {
        logger.info('Tests passed: $passed. Needs recheck: $failedStrings');
      }
    }

    await daemon.callHotReload(fullRestart: true);
    daemon.onLine = null;
  }
}
