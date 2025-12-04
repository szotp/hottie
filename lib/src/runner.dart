import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:hottie/src/ffi.dart';
import 'package:hottie/src/run_tests.dart';
import 'package:hottie/src/script_change.dart';
import 'package:hottie/src/utils/logger.dart';
import 'package:hottie/src/watch.dart';
import 'package:logger/logger.dart';
import 'package:stack_trace/stack_trace.dart';

const _onResultsPortName = 'HottieFrontend.onResults';
const _timeoutDuration = Duration(seconds: 1);

// in VSCode, pressing F5 should run this
// can be run from terminal, but won't reload automatically
// flutter run test/runner.dart -d flutter-tester
HottieFrontend runHottie() {
  return HottieFrontend();
}

Future<void> runHottieIsolate(TestMains testFuncs) async {
  final testPaths = RelativePaths.decode(PlatformDispatcher.instance.defaultRouteName);
  final matches = testFuncs.entries.where((e) => testPaths.paths.contains(e.key)).toList();

  final results = <TestGroupResults>[];

  for (final entry in matches) {
    try {
      results.add(await runTests(entry).timeout(_timeoutDuration));
    } on TimeoutException catch (error, st) {
      results.add(TestGroupResults.timeout(entry.key, error, st));
    }
  }

  final port = IsolateNameServer.lookupPortByName(_onResultsPortName);
  port!.send(results);
}

typedef TestMain = void Function();
typedef TestMains = Map<RelativePath, TestMain>;

class HottieFrontend {
  HottieFrontend() {
    IsolateNameServer.removePortNameMapping(_onResultsPortName);
    IsolateNameServer.registerPortWithName(_port.sendPort, _onResultsPortName);
    _port.cast<List<TestGroupResults>>().forEach(_onResults).withLogging();

    // FOR DEBUGGING ddd
    onReassemble(RelativePaths({})).withLogging();

    _subscriptions.add(
      watchDartFiles().listen(logger.requestReload),
    );

    _load().withLogging();
  }

  Future<void> _load() async {}

  final _port = ReceivePort();
  Set<String> _previouslyFailed = {};
  final _subscriptions = <StreamSubscription<void>>[];

  void dispose() {
    _port.close();
    IsolateNameServer.removePortNameMapping(_onResultsPortName);
    for (final x in _subscriptions) {
      x.cancel().withLogging();
    }
  }

  Future<void> onReassemble(RelativePaths libs) async {
    libs.paths.add('file_1_test.dart');
    libs.paths.addAll(_previouslyFailed);
    if (libs.paths.isEmpty) {
      return;
    }

    spawn('hottie', libs.encode());
  }

  void _onResults(List<TestGroupResults> value) {
    _previouslyFailed = value.where((x) => !x.isSuccess).map((x) => x.path).toSet();

    var passed = 0;
    var skipped = 0;

    for (final testFile in value) {
      passed += testFile.passed.length;
      skipped += testFile.skipped;
      for (final failedTest in testFile.failed) {
        for (final error in failedTest.errors) {
          final trace = Trace.from(error.stackTrace);
          var frame = trace.frames.where((x) => x.uri.toString().contains(testFile.path)).firstOrNull;

          frame ??= trace.frames.where((x) => !x.isCore).firstOrNull;

          frame ??= trace.frames.firstOrNull;

          logger.i('🔴 ${failedTest.name} in ${frame?.location}\n${error.error}');
        }
        return;
      }
    }

    final skippedString = skipped > 0 ? '($skipped skipped)' : '';
    logger.i('✅ $passed $skippedString');
  }
}

extension on Logger {
  void requestReload(String changedFile) {}
}
