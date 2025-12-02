// ignore_for_file: implementation_imports because

import 'dart:async';

import 'package:hottie/src/runner.dart';
import 'package:hottie/src/script_change.dart';
import 'package:test_api/src/backend/live_test.dart';
import 'package:test_core/src/direct_run.dart';
import 'package:test_core/src/runner/engine.dart';
import 'package:test_core/src/runner/reporter.dart';

Future<TestGroupResults> runTests(MapEntry<String, TestMain> test) async {
  final reporter = _Reporter();

  await directRunTests(
    test.value,
    reporterFactory: reporter.watch,
  );

  return reporter.toResults(test.key);
}

class _Reporter extends Reporter {
  late final bool result;
  late final Engine engine;

  _Reporter watch(Engine engine) {
    this.engine = engine;
    return this; // ignore: avoid_returning_this for tear-off
  }

  @override
  void pause() {
    throw UnimplementedError();
  }

  @override
  void resume() {
    throw UnimplementedError();
  }

  TestGroupResults toResults(String path) {
    return TestGroupResults(
      path: path,
      skipped: engine.skipped.length,
      failed: engine.failed.map(_toTestResult).toList(),
      passed: engine.passed.map(_toTestResult).toList(),
    );
  }

  TestResult _toTestResult(LiveTest test) {
    return TestResult(name: test.individualName, errors: test.errors);
  }
}

class TestGroupResults {
  TestGroupResults({
    required this.path,
    required this.skipped,
    required this.failed,
    required this.passed,
  });

  final RelativePath path;

  int skipped;

  List<TestResult> failed;

  List<TestResult> passed;

  bool get isSuccess => failed.isEmpty;

  @override
  String toString() {
    final skippedString = skipped == 0 ? '' : ' ($skipped skipped)';
    final emoji = isSuccess ? '✅' : '🔴';
    final line = '$path: $emoji ${passed.length}/${passed.length + failed.length}$skippedString';

    return line;
  }
}

class TestResult {
  TestResult({
    required this.name,
    required this.errors,
  });

  String name;

  List<AsyncError> errors;
}
