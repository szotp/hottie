#!/usr/bin/env dart

import 'dart:async';

import 'package:hottie/src/daemon.dart';
import 'package:hottie/src/generate_main.dart';
import 'package:hottie/src/script_change.dart';
import 'package:hottie/src/utils/logger.dart';
import 'package:hottie/src/watch.dart';

const String _hottieExtensionName = 'ext.hottie.test';
const String _eventHottieRegistered = 'hottie.registered';
const String _eventHottieUpdate = 'hottie.registered';

class HottieFrontendNew {
  final FlutterDaemon daemon = FlutterDaemon();
  late RelativePaths allTests;
  late final ScriptChangeChecker _scriptChecker;
  bool _isInitialized = false;
  bool _testing = false;
  String? isolateId;

  Future<void> run({required RelativePaths paths, String? existingHottiePath}) async {
    allTests = paths.paths.isNotEmpty ? paths : findTestsInCurrentDirectory();

    final hottiePath = await generateMain(RelativePaths.empty);

    daemon.setEventHandler(_eventHottieRegistered, _onHottieRegistered);
    await daemon.start(path: hottiePath);

    _scriptChecker = ScriptChangeChecker(daemon.vmService);

    await generateMain(allTests);
    await daemon.callHotReload();
    _isInitialized = true;
    watchDartFiles().forEach((_) => runCycle()).withLogging();
    daemon.setKeyHandler('t', (_) => testAll());
  }

  Future<void> testAll() {
    final all = allTests;
    if (all == null) {
      logger.warning('testAll not possible because allTests is null');
    }

    return runCycle(all);
  }

  Future<void> runCycle([RelativePaths? forcePaths]) async {
    if (_testing) {
      logger.warning('Tests still running.');
      return;
    }

    final progress = printer.start('Testing...');

    try {
      _testing = true;
      daemon.setEventHandler(_eventHottieUpdate, (event) {
        final text = event.params['text'] as String;
        if (_progressPattern.matchAsPrefix(text) != null && !text.contains('[E]')) {
          progress.update(text);
        } else {
          printer.writeln(text);
        }
      });

      final paths = forcePaths ?? (await _scriptChecker.checkLibraries(isolateId!));
      await callHottieTest(paths);
      daemon.setEventHandler(_eventHottieUpdate, (_) {});
      progress.finish('Tests finished');
      await daemon.callHotReload(fullRestart: true);
    } finally {
      _testing = false;
    }
  }

  void _onHottieRegistered(DaemonEvent parsed) {
    isolateId = parsed.params['isolateId'] as String;
    if (!_isInitialized) {
      return;
    }
    _scriptChecker.checkLibraries(isolateId!).withLogging();
  }

  Future<String> callHottieTest(RelativePaths paths) async {
    logger.finest('Testing: ${paths.describe()}');

    final result = await daemon.callServiceExtension(_hottieExtensionName, {
      'paths': paths.encode(),
    });
    return result.result['status'] as String;
  }
}

final _progressPattern = RegExp(r'\d\d:\d\d');
