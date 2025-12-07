#!/usr/bin/env dart

import 'dart:async';
import 'dart:io';

import 'package:hottie/hottie_insider.dart';
import 'package:hottie/src/daemon.dart';
import 'package:hottie/src/generate_main.dart';
import 'package:hottie/src/script_change.dart';
import 'package:hottie/src/utils/logger.dart';
import 'package:hottie/src/watch.dart';

// ignore: unused_element --- only for debug console
HottieFrontendNew? _frontend;

class HottieFrontendNew {
  final FlutterDaemon daemon = FlutterDaemon();
  late RelativePaths allTests;
  late final ScriptChangeChecker _scriptChecker;
  bool _isInitialized = false;
  StdoutProgress? _testing;
  String? isolateId;

  Future<void> run({required RelativePaths paths, String? existingHottiePath}) async {
    final String hottiePath;

    if (existingHottiePath != null) {
      assert(File(existingHottiePath).existsSync(), '$existingHottiePath does not exist');
      hottiePath = existingHottiePath;
    } else {
      (hottiePath, _) = await generateMain(paths.paths.isNotEmpty ? paths : null);
    }

    daemon.registerEventHandler(HottieRegistered.event, _onHottieRegistered);
    daemon.registerEventHandler(TestFinished.event, _onTestFinished);
    daemon.registerKeyHandler('t', (_) => testAll());
    await daemon.start(path: hottiePath);

    _scriptChecker = ScriptChangeChecker(daemon.vmService);
    _isInitialized = true;

    hotReloadAutomatically().withLogging();
    watchDartFiles().forEach((_) => runCycle()).withLogging();

    _frontend = this;

    testAll();
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

  Future<void> runCycle() async {
    if (_testing != null) {
      return;
    }

    stdout.writeln('\n');
    _testing = printer.start('Scanning!!!!!');

    try {
      await daemon.callHotReload();

      final paths = await _scriptChecker.checkLibraries(isolateId!);

      if (paths.paths.isEmpty) {
        _testing?.finish('Nothing to test');
        return;
      }

      _testing?.update('Testing ${paths.describe()}');

      await callHottieTest(paths);

      await daemon.callHotReload(fullRestart: true);
    } catch (error, stackTrace) {
      logger.severe(error, error, stackTrace);
    } finally {
      _testing = null;
    }
  }

  void _onHottieRegistered(HottieRegistered parsed) {
    allTests = RelativePaths(parsed.paths);
    isolateId = parsed.isolateId;
    if (!_isInitialized) {
      return;
    }
    _scriptChecker.checkLibraries(isolateId!).withLogging();
  }

  void _onTestFinished(TestFinished parsed) {
    if (parsed.error != null) {
      logger.warning('Test "${parsed.name}" failed\n${parsed.error}', null, parsed.stackTrace);
    }

    _testing?.update('');
  }

  Future<void> callHottieTest(RelativePaths paths) async {
    logger.finest('Testing: ${paths.describe()}');

    final r = await daemon.callServiceExtension(hottieExtensionName, {
      'paths': paths.encode(),
    });

    final parsed = TestResults.fromJson(r.result);

    if (parsed.failed == 0) {
      _testing?.finish('${parsed.passed} tests passed.');
    } else {
      _testing?.finish('${parsed.failed} tests failed');
    }
  }
}
