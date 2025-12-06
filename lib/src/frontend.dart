#!/usr/bin/env dart

import 'dart:async';

import 'package:hottie/src/daemon.dart';
import 'package:hottie/src/generate_main.dart';
import 'package:hottie/src/script_change.dart';
import 'package:hottie/src/utils/logger.dart';
import 'package:hottie/src/watch.dart';

// ignore: unused_element --- only for debug console
HottieFrontendNew? _frontend;

class HottieFrontendNew {
  final FlutterDaemon daemon = FlutterDaemon();
  late final RelativePaths allTests;
  late final ScriptChangeChecker _scriptChecker;
  bool _isInitialized = false;
  bool _isTesting = false;
  String? isolateId;
  final Set<RelativePath> _failedTests = {};

  Future<void> run(RelativePaths paths) async {
    // Directory.current = '/Users/pawelszot/Development/provider/packages/provider';
    final (hottiePath, allTests) = await generateMain(paths);
    this.allTests = allTests;

    daemon.handlers['hottie.registered'] = _onHottieRegistered;
    daemon.handlers['hottie.fail'] = _onHottieFail;
    await daemon.start(path: hottiePath);

    _scriptChecker = ScriptChangeChecker(daemon.vmService);
    _isInitialized = true;

    watchDartFiles().forEach(_onFilesChanged).withLogging();

    testAll();
    _frontend = this;
  }

  void dispose() {
    _frontend = null;
  }

  void testAll() {
    final all = allTests;
    if (all == null) {
      logger.warning('testAll not possible because allTests is null');
    }

    callHottieTest(all).withLogging();
  }

  /// Executes when any dart file changes.
  /// Causes hot reload, which eventually leads to _onIsolateReload being called.
  Future<void> _onFilesChanged(String changedFile) async {
    logger.fine('_onFilesChanged: $changedFile isTesting: $_isTesting');

    if (_isTesting) {
      return;
    }

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
    logger.info('Testing: ${paths.describe()}');

    final DaemonResult r;

    try {
      _isTesting = true;
      r = await daemon.callServiceExtension('ext.hottie.test', {
        'paths': paths.encode(),
      });
    } catch (error, stackTrace) {
      logger.shout('callHottieTest failed', error, stackTrace);
      return;
    } finally {
      _isTesting = false;
    }

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
  }
}
