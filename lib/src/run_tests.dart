// ignore_for_file: implementation_imports because

import 'dart:async';
import 'dart:io';

import 'package:hottie/src/utils/logger.dart';
import 'package:test_core/src/direct_run.dart';
import 'package:test_core/src/runner/reporter/json.dart';

const _direct = false;

Future<bool> runTests(void Function() testMain) async {
  final sw = Stopwatch()..start();
  final bool result;

  if (_direct) {
    result = await _runTestsDirect(testMain);
  } else {
    result = await _runTestsDefault(testMain);
  }

  logger('runTests ${sw.elapsedMilliseconds}ms');
  return result;
}

Future<bool> _runTestsDefault(void Function() testMain) async {
  final completer = Completer<bool>();

  runZoned(
    testMain,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        final split = line.split(':');
        // parent.print(zone, line);
        switch (split.last.trim()) {
          case 'All tests passed!':
            completer.complete(true);
          case 'All tests skipped.':
            completer.complete(true);
          case 'Some tests failed.':
            completer.complete(false);
        }
      },
    ),
  );

  await completer.future;
  return true;
}

Future<bool> _runTestsDirect(void Function() testMain) async {
  return directRunTests(
    testMain,
    reporterFactory: (engine) =>
        JsonReporter.watch(engine, stdout, isDebugRun: true),
  );
}

class TestGroupResults {
  TestGroupResults({
    required this.skipped,
    required this.failed,
    required this.passed,
  });

  int skipped;

  List<TestResult> failed;

  List<TestResult> passed;
}

class TestResult {
  TestResult({
    required this.name,
    required this.errors,
  });

  String name;

  List<TestResultError> errors;
}

class TestResultError {
  TestResultError({
    required this.message,
  });

  String message;
}
