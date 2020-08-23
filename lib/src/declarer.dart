import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:test_api/src/backend/declarer.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/group.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/group_entry.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/test.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/suite.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/live_test.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/suite_platform.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/runtime.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/invoker.dart'; // ignore: implementation_imports

import 'package:flutter_test/flutter_test.dart';
import 'model.dart';
import 'service.dart';

// taken from test_compat.dart

class MyReporter extends _Reporter {}

Future<TestGroupResults> runTestsFromRawCallback(int input) {
  return runTests(PluginUtilities.getCallbackFromHandle(
      CallbackHandle.fromRawHandle(input)));
}

class _HottieBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  void scheduleWarmUpFrame() {}
}

Future<TestGroupResults> runTests(TestMain input) async {
  if (WidgetsBinding.instance == null) {
    _HottieBinding();
  }

  final binding = WidgetsBinding.instance as _HottieBinding;
  binding.window.physicalSizeTestValue = Size(800, 600);

  final sw = Stopwatch()..start();
  final reporter = MyReporter();

  await Invoker.guard<Future<void>>(() async {
    final declarer = Declarer()..declare(input);
    final Group group = declarer.build();
    final Suite suite = Suite(group, SuitePlatform(Runtime.vm));
    await _runGroup(suite, group, <Group>[], reporter);
    reporter._onDone();
  });

  sw.stop();

  return TestGroupResults(
    skipped: reporter.skipped.length,
    failed: reporter.failed.map(_mapResult).toList(),
    passed: reporter.passed.map(_mapResult).toList(),
  );
}

TestResultError _mapError(AsyncError error) {
  return TestResultError(error.toString());
}

TestResult _mapResult(LiveTest test) {
  return TestResult(test.test.name, test.errors.map(_mapError).toList());
}

Future<void> _runGroup(Suite suiteConfig, Group group, List<Group> parents,
    _Reporter reporter) async {
  parents.add(group);
  try {
    final bool skipGroup = group.metadata.skip;
    bool setUpAllSucceeded = true;
    if (!skipGroup && group.setUpAll != null) {
      final LiveTest liveTest =
          group.setUpAll.load(suiteConfig, groups: parents);
      await _runLiveTest(suiteConfig, liveTest, reporter, countSuccess: false);
      setUpAllSucceeded = liveTest.state.result.isPassing;
    }
    if (setUpAllSucceeded) {
      for (final GroupEntry entry in group.entries) {
        if (entry is Group) {
          await _runGroup(suiteConfig, entry, parents, reporter);
        } else if (entry.metadata.skip) {
          await _runSkippedTest(suiteConfig, entry as Test, parents, reporter);
        } else {
          final Test test = entry as Test;
          await _runLiveTest(
              suiteConfig, test.load(suiteConfig, groups: parents), reporter);
        }
      }
    }
    // Even if we're closed or setUpAll failed, we want to run all the
    // teardowns to ensure that any state is properly cleaned up.
    if (!skipGroup && group.tearDownAll != null) {
      final LiveTest liveTest =
          group.tearDownAll.load(suiteConfig, groups: parents);
      await _runLiveTest(suiteConfig, liveTest, reporter, countSuccess: false);
    }
  } finally {
    parents.remove(group);
  }
}

Future<void> _runSkippedTest(Suite suiteConfig, Test test, List<Group> parents,
    _Reporter reporter) async {
  final LocalTest skipped =
      LocalTest(test.name, test.metadata, () {}, trace: test.trace);
  if (skipped.metadata.skipReason != null) {
    print('Skip: ${skipped.metadata.skipReason}');
  }
  final LiveTest liveTest = skipped.load(suiteConfig);
  reporter._onTestStarted(liveTest);
  reporter.skipped.add(skipped);
}

Future<void> _runLiveTest(
    Suite suiteConfig, LiveTest liveTest, _Reporter reporter,
    {bool countSuccess = true}) async {
  reporter._onTestStarted(liveTest);
  // Schedule a microtask to ensure that [onTestStarted] fires before the
  // first [LiveTest.onStateChange] event.
  await Future<void>.microtask(liveTest.run);
  // Once the test finishes, use await null to do a coarse-grained event
  // loop pump to avoid starving non-microtask events.
  await null;
  final bool isSuccess = liveTest.state.result.isPassing;
  if (isSuccess) {
    reporter.passed.add(liveTest);
  } else {
    reporter.failed.add(liveTest);
  }
}

abstract class _Reporter {
  final List<LiveTest> passed = <LiveTest>[];
  final List<LiveTest> failed = <LiveTest>[];
  final List<Test> skipped = <Test>[];

  void _onTestStarted(LiveTest liveTest) {}
  void _onDone() {}
}
