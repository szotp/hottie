// ignore_for_file: implementation_imports required for test declarer
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:test_api/src/backend/declarer.dart';
import 'package:test_api/src/backend/group.dart';
import 'package:test_api/src/backend/invoker.dart';
import 'package:test_api/src/backend/live_test.dart';
import 'package:test_api/src/backend/runtime.dart';
import 'package:test_api/src/backend/suite.dart';
import 'package:test_api/src/backend/suite_platform.dart';
import 'package:test_api/src/backend/test.dart';

Future<void> hottie(Map<String, void Function()> tests) async {
  Future<bool> run(Set<String> allowed) async {
    for (final test in tests.entries) {
      final r = await declareAndRunTests(test.value);

      if (r.failed.isNotEmpty) {
        return false;
      }
    }

    return true;
  }

  registerExtension('ext.hottie.test', (_, args) async {
    print('testing');
    final result = await run({});
    print('testing done');

    final json = {
      'ok': result,
    };
    final resultString = jsonEncode(json);
    print('returning $resultString');
    return ServiceExtensionResponse.result(resultString);
  });

  print('[{"event":"hottieWaiting"}]');
}

Future<Reporter> declareAndRunTests(void Function() tests) async {
  final reporter = Reporter(); // disable color when run directly.
  final declarer = Declarer();
  declarer.declare(tests);

  await Invoker.guard<Future<void>>(() async {
    // ignore: this self-call is safe since it will just fetch the declarer instance
    final group = declarer.build();
    final suite = Suite(group, SuitePlatform(Runtime.vm));

    await _runGroup(suite, group, <Group>[], reporter);

    reporter._onDone();
  });

  return reporter;
}

Future<void> _runGroup(
  Suite suiteConfig,
  Group group,
  List<Group> parents,
  Reporter reporter,
) async {
  parents.add(group);
  try {
    final skipGroup = group.metadata.skip;
    var setUpAllSucceeded = true;
    if (!skipGroup && group.setUpAll != null) {
      final liveTest = group.setUpAll!.load(suiteConfig, groups: parents);
      await _runLiveTest(suiteConfig, liveTest, reporter, countSuccess: false);
      setUpAllSucceeded = liveTest.state.result.isPassing;
    }
    if (setUpAllSucceeded) {
      for (final entry in group.entries) {
        if (entry is Group) {
          await _runGroup(suiteConfig, entry, parents, reporter);
        } else if (entry.metadata.skip) {
          await _runSkippedTest(suiteConfig, entry as Test, parents, reporter);
        } else {
          final test = entry as Test;
          await _runLiveTest(suiteConfig, test.load(suiteConfig, groups: parents), reporter);
        }
      }
    }
    // Even if we're closed or setUpAll failed, we want to run all the
    // teardowns to ensure that any state is properly cleaned up.
    if (!skipGroup && group.tearDownAll != null) {
      final liveTest = group.tearDownAll!.load(suiteConfig, groups: parents);
      await _runLiveTest(suiteConfig, liveTest, reporter, countSuccess: false);
    }
  } finally {
    parents.remove(group);
  }
}

Future<void> _runLiveTest(
  Suite suiteConfig,
  LiveTest liveTest,
  Reporter reporter, {
  bool countSuccess = true,
}) async {
  reporter._onTestStarted(liveTest);
  // Schedule a microtask to ensure that [onTestStarted] fires before the
  // first [LiveTest.onStateChange] event.
  await Future<void>.microtask(liveTest.run);
  // Once the test finishes, use await null to do a coarse-grained event
  // loop pump to avoid starving non-microtask events.
  await null;
  final isSuccess = liveTest.state.result.isPassing;
  if (isSuccess) {
    reporter.passed.add(liveTest);
  } else {
    reporter.failed.add(liveTest);
  }
}

Future<void> _runSkippedTest(
  Suite suiteConfig,
  Test test,
  List<Group> parents,
  Reporter reporter,
) async {
  final skipped = LocalTest(test.name, test.metadata, () {}, trace: test.trace);
  if (skipped.metadata.skipReason != null) {
    reporter.log('Skip: ${skipped.metadata.skipReason}');
  }
  final liveTest = skipped.load(suiteConfig);
  reporter._onTestStarted(liveTest);
  reporter.skipped.add(skipped);
}

/// A reporter that prints each test on its own line.
///
/// This is currently used in place of `CompactReporter` by `lib/test.dart`,
/// which can't transitively import `dart:io` but still needs access to a runner
/// so that test files can be run directly. This means that until issue 6943 is
/// fixed, this must not import `dart:io`.
class Reporter {
  final List<LiveTest> passed = <LiveTest>[];
  final List<LiveTest> failed = <LiveTest>[];
  final List<Test> skipped = <Test>[];

  void _onTestStarted(LiveTest liveTest) {}
  void _onDone() {}
  void log(String line) {}
}
