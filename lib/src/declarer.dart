import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hottie/src/logger.dart';
import 'package:hottie/src/model.g.dart';
import 'package:hottie/src/test_compat.dart';
import 'package:test_api/src/backend/live_test.dart'; // ignore: implementation_imports

typedef TestMain = void Function();

void setTestDirectory(String root) {
  logHottie('current directory: $root');
  Directory.current = root;
}

Future<TestGroupResults> runTestsFromRawCallback(int input) {
  return runTests(PluginUtilities.getCallbackFromHandle(CallbackHandle.fromRawHandle(input))! as TestMain);
}

Future<TestGroupResults> runTests(TestMain input) async {
  final binding = AutomatedTestWidgetsFlutterBinding.ensureInitialized();
  binding.platformDispatcher.implicitView?.physicalSize = const Size(800, 600); // for error when widget testing

  final sw = Stopwatch()..start();
  final reporter = await declareAndRunTests(input);

  sw.stop();

  return TestGroupResults(
    skipped: reporter.skipped.length,
    failed: reporter.failed.map(_mapResult).toList(),
    passed: reporter.passed.map(_mapResult).toList(),
  );
}

TestResultError _mapError(AsyncError error) {
  return TestResultError(message: error.toString());
}

TestResult _mapResult(LiveTest test) {
  return TestResult(name: test.test.name, errors: test.errors.map(_mapError).toList());
}
