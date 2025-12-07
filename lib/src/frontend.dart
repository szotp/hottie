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
    allTests = paths.paths.isNotEmpty ? paths : findTestsInCurrentDirectory();

    final hottiePath = await _prepareHottiePath(existingHottiePath);

    daemon.setEventHandler(hottieRegisteredEventName, _onHottieRegistered);
    daemon.setKeyHandler('t', (_) => testAll());
    await daemon.start(path: hottiePath);

    _scriptChecker = ScriptChangeChecker(daemon.vmService);
    _isInitialized = true;

    watchDartFiles().forEach((_) => runCycle()).withLogging();

    _frontend = this;

    //testAll().withLogging();
  }

  Future<String> _prepareHottiePath(String? existingHottiePath) async {
    final String hottiePath;
    if (existingHottiePath != null) {
      assert(File(existingHottiePath).existsSync(), '$existingHottiePath does not exist');
      hottiePath = existingHottiePath;
    } else {
      hottiePath = await generateMain(allTests);
    }
    return hottiePath;
  }

  void dispose() {
    _frontend = null;
  }

  Future<void> testAll() {
    final all = allTests;
    if (all == null) {
      logger.warning('testAll not possible because allTests is null');
    }

    return runCycle(all);
  }

  Future<void> runCycle([RelativePaths? forcePaths]) async {
    if (_testing != null) {
      return;
    }

    final onComplete = Completer<String>();
    _testing = printer.start('Scanning...');

    daemon.setEventHandler(hottieReportEventName, (event) {
      final line = event.params['line'] as String;

      if (line.contains('All tests passed!') || line.contains('Some tests failed')) {
        onComplete.complete(line);
      } else if (line.isNotEmpty) {
        _testing?.update(line);
      }
    });

    try {
      await daemon.callHotReload();

      final paths = forcePaths ?? (await _scriptChecker.checkLibraries(isolateId!));

      if (paths.paths.isEmpty) {
        _testing?.finish('Nothing to test');
        return;
      }

      printer.writeln('Testing ${paths.describe()}');

      await callHottieTest(paths);

      _testing?.finish(await onComplete.future);
    } catch (error, stackTrace) {
      logger.severe(error, error, stackTrace);
    } finally {
      _testing = null;
      daemon.onLine = null;
    }

    await daemon.callHotReload(fullRestart: true);
  }

  void _onHottieRegistered(DaemonEvent parsed) {
    isolateId = parsed.params['isolateId'] as String;
    if (!_isInitialized) {
      return;
    }
    _scriptChecker.checkLibraries(isolateId!).withLogging();
  }

  Future<void> callHottieTest(RelativePaths paths) async {
    logger.finest('Testing: ${paths.describe()}');

    await daemon.callServiceExtension(hottieExtensionName, {
      'paths': paths.encode(),
    });
  }
}
