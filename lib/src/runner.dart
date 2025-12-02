import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:hottie/src/run_tests.dart';
import 'package:hottie/src/script_change.dart';
import 'package:hottie/src/utils/logger.dart';
import 'package:stack_trace/stack_trace.dart';

const _onResultsPortName = 'HottieFrontend.onResults';

// in VSCode, pressing F5 should run this
// can be run from terminal, but won't reload automatically
// flutter run test/runner.dart -d flutter-tester
HottieFrontend runHottie() => HottieFrontend();

Future<void> runHottieIsolate(TestMains testFuncs) async {
  final testPaths = RelativePaths.decode(PlatformDispatcher.instance.defaultRouteName);
  final matches = testFuncs.entries.where((e) => testPaths.paths.contains(e.key)).toList();

  final results = <TestGroupResults>[];

  for (final entry in matches) {
    results.add(await runTests(entry).timeout(const Duration(seconds: 1)));
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
    _port.cast<List<TestGroupResults>>().forEach(_onResults).ignoreWithLogging();
    _observer.observe().forEach(onReassemble).ignoreWithLogging();
    onReassemble(RelativePaths({})).ignoreWithLogging();
  }

  late final StreamSubscription<void> _reloader;
  final _observer = ScriptChangeChecker();
  final _port = ReceivePort();
  Set<String> _previouslyFailed = {};

  void dispose() {
    _observer.dispose();
    _port.close();
    IsolateNameServer.removePortNameMapping(_onResultsPortName);
    _reloader.cancel().ignoreWithLogging();
  }

  Future<void> onReassemble(RelativePaths libs) async {
    libs.paths.add('file_1_test.dart');
    libs.paths.addAll(_previouslyFailed);
    if (libs.paths.isEmpty) {
      return;
    }

    // spawn('hottie', libs.encode());
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
          final frame = Trace.from(error.stackTrace).frames.where((x) => x.uri.toString().contains(testFile.path)).firstOrNull;

          if (frame != null) {
            logger('🔴 ${failedTest.name} in ${frame.location}');
          }

          logger(error.error.toString());
        }
        return;
      }
    }

    final skippedString = skipped > 0 ? '($skipped skipped)' : '';
    logger('✅ $passed $skippedString');
  }
}
