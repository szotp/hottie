// ignore_for_file: implementation_imports required for test declarer

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:test_api/src/backend/declarer.dart';
import 'package:test_api/src/backend/group.dart';
import 'package:test_api/src/backend/invoker.dart';
import 'package:test_api/src/backend/live_test.dart';
import 'package:test_api/src/backend/runtime.dart';
import 'package:test_api/src/backend/suite.dart';
import 'package:test_api/src/backend/suite_platform.dart';
import 'package:test_api/src/backend/test.dart';

Future<void> hottie(Map<String, void Function()> tests, {bool runNormally = false}) async {
  Future<TestResults> run(Set<String> allowed) async {
    final reporter = TestResults();
    for (final test in tests.entries.where((x) => allowed.contains(x.key))) {
      reporter.path = test.key;
      await declareAndRunTests(reporter, test.value);
    }

    return reporter;
  }

  registerExtension('ext.hottie.test', (_, args) async {
    final paths = (jsonDecode(args['paths']!) as List).toSet().cast<String>();
    final reporter = await run(paths);
    final resultString = jsonEncode(reporter);
    return ServiceExtensionResponse.result(resultString);
  });

  _sendEvent('hottie.registered', {'isolateId': Service.getIsolateId(Isolate.current)});

  if (runNormally) {
    for (final test in tests.values) {
      test();
    }
  }
}

Future<void> declareAndRunTests(TestResults reporter, void Function() tests) async {
  final declarer = Declarer();
  declarer.declare(tests);

  await Invoker.guard<Future<void>>(() async {
    final group = declarer.build();
    final suite = Suite(group, SuitePlatform(Runtime.vm));

    await _runGroup(suite, group, <Group>[], reporter);
  });
}

Future<void> _runGroup(
  Suite suiteConfig,
  Group group,
  List<Group> parents,
  TestResults reporter,
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
          reporter._onTestSkipped();
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
  TestResults reporter, {
  bool countSuccess = true,
}) async {
  await Future<void>.microtask(liveTest.run);
  // Once the test finishes, use await null to do a coarse-grained event
  // loop pump to avoid starving non-microtask events.
  await null;
  reporter._onTestFinished(liveTest);
}

class TestResults {
  int _passed = 0;
  int _skipped = 0;
  final Set<String> _failed = {};

  String path = '';

  void _onTestFinished(LiveTest liveTest) {
    final isSuccess = liveTest.state.result.isPassing;
    if (isSuccess) {
      _passed++;
    } else {
      final error = liveTest.errors.first;
      _failed.add(path);
      _onError(liveTest.individualName, error);
    }
  }

  void _onError(String testName, AsyncError error) {
    final info = {
      'event': 'hottie.fail',
      'params': {
        'path': path,
        'name': testName,
        'error': error.error.toString(),
        'stackTrace': error.stackTrace.toString(),
      },
    };
    stdout.writeln(jsonEncode([info]));
  }

  void _onTestSkipped() {
    _skipped++;
  }

  Map<String, dynamic> toJson() => {
        'passed': _passed,
        'skipped': _skipped,
        'failed': _failed.toList(),
      };
}

void _sendEvent(String name, Map<String, dynamic> params) {
  final info = {
    'event': name,
    'params': params,
  };
  stdout.writeln(jsonEncode([info]));
}
