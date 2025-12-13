#!/usr/bin/env dart

import 'dart:async';

import 'package:ansicolor/ansicolor.dart';
import 'package:hottie/src/assets.dart';
import 'package:hottie/src/daemon.dart';
import 'package:hottie/src/generate_main.dart';
import 'package:hottie/src/script_change.dart';
import 'package:hottie/src/utils/logger.dart';
import 'package:hottie/src/watch.dart';

const String _hottieExtensionName = 'ext.hottie.test';
const String _eventHottieRegistered = 'hottie.registered';
const String _eventHottieUpdate = 'hottie.update';

class HottieFrontendNew {
  final FlutterDaemon daemon = FlutterDaemon();
  late Files allTests;
  late final ScriptChangeChecker _scriptChecker;
  bool _isInitialized = false;
  bool _testing = false;
  String? isolateId;
  Uri? assetsUri;

  Future<void> run({required Files paths, String? existingHottiePath}) async {
    allTests = paths.uris.isNotEmpty ? paths : findTestsInCurrentDirectory();

    final hottieUri = await generateMain(allTests);

    daemon.setEventHandler(_eventHottieRegistered, _onHottieRegistered);
    await daemon.start(hottieUri: hottieUri);

    _scriptChecker = ScriptChangeChecker(daemon.vmService);

    //await generateMain(allTests);
    //await daemon.callHotReload();
    _isInitialized = true;
    watchDartFiles().forEach((_) => runCycle()).withLogging();
    daemon.setKeyHandler('t', (_) => testAll());

    assetsUri = findAssetsFolder();
    testAll().withLogging();
  }

  Future<void> testAll() {
    final all = allTests;
    if (all == null) {
      logger.warning('testAll not possible because allTests is null');
    }

    return runCycle(all);
  }

  Future<void> runCycle([Files? forcePaths]) async {
    if (_testing) {
      logger.warning('Tests still running.');
      return;
    }

    final progress = printer.start('Testing...');

    try {
      _testing = true;
      await daemon.callHotReload();
      final paths = forcePaths ?? (await _scriptChecker.checkLibraries(isolateId!));
      if (paths.uris.isEmpty) {
        progress.finish('Nothing to test');
        _testing = false;
        return;
      }

      final ansi = AnsiPen()..blue(bg: true);
      printer.writeln('\x1B[2J\x1B[H');
      printer.writeln(ansi('Testing: ${paths.describe()}'));
      final regex = RegExp(r'\d\d:\d\d');
      daemon.onRegularText = (line) {
        if (regex.matchAsPrefix(line) != null) {
          progress.update(line);
        } else if (line.trim().isNotEmpty) {
          printer.writeln(line);
        }
      };

      daemon.setEventHandler(_eventHottieUpdate, (event) {
        final text = event.params['text'] as String;
        if (_progressPattern.matchAsPrefix(text) != null && !text.contains('[E]')) {
          progress.update(text);
        } else {
          printer.writeln(text);
        }
      });

      final status = await callHottieTest(paths);
      daemon.setEventHandler(_eventHottieUpdate, (_) {});
      progress.finish(status);
      await daemon.callHotReload(fullRestart: true);
    } catch (error) {
      progress.finish(error.toString());
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

  Future<String> callHottieTest(Files paths) async {
    if (paths.uris.isEmpty) {
      return 'Nothing to test';
    }

    logger.finest('Testing: ${paths.describe()}');

    final result = await daemon.callServiceExtension(_hottieExtensionName, {'paths': paths.encode(), 'assets': assetsUri!.toFilePath()});
    return result.result['status'] as String;
  }
}

final _progressPattern = RegExp(r'\d\d:\d\d');
