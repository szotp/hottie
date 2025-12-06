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

typedef TestMap = Map<String, void Function()>;
typedef TestMapFactory = TestMap Function();
const String hottieExtensionName = 'ext.hottie.test';

Future<void> hottie(TestMapFactory tests, {bool runNormally = false}) async {
  Future<TestResults> run(Set<String> allowed) async {
    final reporter = TestResults();
    for (final test in tests().entries.where((x) => allowed.contains(x.key))) {
      reporter.path = test.key;
      await declareAndRunTests(reporter, test.value);
    }

    return reporter;
  }

  registerExtension(hottieExtensionName, (_, args) async {
    final paths = (jsonDecode(args['paths']!) as List).toSet().cast<String>();
    final reporter = await run(paths);
    final resultString = jsonEncode(reporter);
    return ServiceExtensionResponse.result(resultString);
  });

  HottieRegistered(Service.getIsolateId(Isolate.current)!, tests().keys.toSet()).send();

  if (runNormally) {
    for (final test in tests().values) {
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
  TestResults([this.passed = 0, this.skipped = 0, this.failed = 0]);

  factory TestResults.fromJson(Map<String, dynamic> result) {
    return TestResults(
      result['passed'] as int,
      result['skipped'] as int,
      result['failed'] as int,
    );
  }
  int passed;
  int skipped;
  int failed;

  String path = '';

  void _onTestFinished(LiveTest liveTest) {
    final isSuccess = liveTest.state.result.isPassing;
    if (isSuccess) {
      passed++;

      TestFinished(liveTest.individualName, path, null, null).send();
    } else {
      final error = liveTest.errors.first;
      failed++;
      TestFinished(liveTest.individualName, path, error.error.toString(), error.stackTrace).send();
    }
  }

  void _onTestSkipped() {
    skipped++;
  }

  Map<String, dynamic> toJson() => {
        'passed': passed,
        'skipped': skipped,
        'failed': failed,
      };
}

class EventHandle<T> {
  const EventHandle(this.name, this.mapper);
  final String name;
  final T Function(Map<String, dynamic>) mapper;

  void send(T event) {
    final info = {
      'event': name,
      'params': (event as dynamic).toJson(),
    };
    stdout.writeln(jsonEncode([info]));
  }
}

class HottieRegistered {
  HottieRegistered(this.isolateId, this.paths);

  factory HottieRegistered.fromJson(Map<String, dynamic> json) {
    return HottieRegistered(
      json['isolateId'] as String,
      (json['paths'] as List).toSet().cast<String>(),
    );
  }
  static const EventHandle<HottieRegistered> event = EventHandle('hottie.registered', HottieRegistered.fromJson);

  final String isolateId;
  final Set<String> paths;

  void send() => event.send(this);

  Map<String, dynamic> toJson() => {
        'isolateId': isolateId,
        'paths': paths.toList(),
      };
}

class TestFinished {
  TestFinished(this.name, this.path, this.error, this.stackTrace);
  factory TestFinished.fromJson(Map<String, dynamic> json) {
    return TestFinished(
      json['name'] as String,
      json['path'] as String,
      json['error'] as String?,
      json['stackTrace'] != null ? StackTrace.fromString(json['stackTrace'] as String) : null,
    );
  }
  static const EventHandle<TestFinished> event = EventHandle('hottie.testFinished', TestFinished.fromJson);

  final String name;
  final String path;
  final String? error;
  final StackTrace? stackTrace;

  Map<String, dynamic> toJson() => {
        'name': name,
        'path': path,
        'error': error,
        'stackTrace': stackTrace?.toString(),
      };

  void send() => event.send(this);
}
