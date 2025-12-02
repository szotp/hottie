// ignore_for_file: unused_import // for test_core

import 'dart:convert';
import 'dart:isolate';
import 'dart:ui';

import 'package:hottie/src/ffi.dart';
import 'package:hottie/src/run_tests.dart';
import 'package:hottie/src/script_change.dart';
import 'package:hottie/src/utils/logger.dart';
import 'package:hottie/src/watcher.dart';

const _onResultsPortName = 'HottieFrontend.onResults';

// in VSCode, pressing F5 should run this
// can be run from terminal, but won't reload automatically
// flutter run test/runner.dart -d flutter-tester
HottieFrontend runHottie() => HottieFrontend();

Future<void> runHottieIsolate(Map<RelativePath, TestMain> testFuncs) async {
  final testPaths =
      (jsonDecode(PlatformDispatcher.instance.defaultRouteName) as List)
          .cast<RelativePath>()
          .toSet();
  final matches =
      testFuncs.entries.where((e) => testPaths.contains(e.key)).toList();
  final keys = matches.map((x) => x.key).join(', ');

  logger('directRunTests: $keys');

  void testMain() {
    for (final entry in matches) {
      entry.value();
    }
  }

  final success = await runTests(testMain);

  final port = IsolateNameServer.lookupPortByName(_onResultsPortName);
  port?.send(success);
}

typedef TestMain = void Function();

class HottieFrontend {
  HottieFrontend() {
    IsolateNameServer.removePortNameMapping(_onResultsPortName);
    IsolateNameServer.registerPortWithName(_port.sendPort, _onResultsPortName);
    _port.forEach(_onResults).ignoreWithLogging();
    _observer.observe().forEach(onReassemble).ignoreWithLogging();
    onReassemble([]).ignoreWithLogging();
  }
  final _observer = ScriptChangeChecker();
  final _port = ReceivePort();

  void dispose() {
    _observer.dispose();
    _port.close();
    IsolateNameServer.removePortNameMapping(_onResultsPortName);
  }

  Future<void> onReassemble(List<String> libs) async {
    libs.add('file_1_test.dart');
    if (libs.isEmpty) {
      return;
    }

    final string = jsonEncode(libs);
    spawn('hottie', string);
  }

  void _onResults(dynamic value) {
    logger('_onResults $value');
  }
}
