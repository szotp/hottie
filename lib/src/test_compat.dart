/*
Copy of https://github.com/flutter/flutter/blob/master/packages/flutter_test/lib/src/test_compat.dart
- renamed from _Reporter to Reporter
- removed printing from Reporter
- commented out _declarer
- added declareAndRunTests that calls Invoker.guard the same way as _declarer
- removed unused methods
*/

// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// @docImport 'package:test_api/backend.dart';
/// @docImport 'package:test_api/scaffolding.dart';
library;

import 'dart:async';

import 'package:hottie/src/logger.dart';
import 'package:test_api/src/backend/declarer.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/group.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/group_entry.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/invoker.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/live_test.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/runtime.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/suite.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/suite_platform.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/test.dart'; // ignore: implementation_imports

Future<Reporter> declareAndRunTests(void Function() tests) async {
  final sw = Stopwatch()..start();
  final reporter = Reporter(); // disable color when run directly.
  // ignore: no_leading_underscores_for_local_identifiers
  final _declarer = Declarer();
  _declarer.declare(tests);
  logHottie('runTests X ${sw.elapsedMilliseconds}ms');
  await Invoker.guard<Future<void>>(() async {
    logHottie('runTests ${sw.elapsedMilliseconds}ms');
    // ignore: recursive_getters, this self-call is safe since it will just fetch the declarer instance
    final Group group = _declarer.build();
    final suite = Suite(group, SuitePlatform(Runtime.vm));
    logHottie('runTests rg ${sw.elapsedMilliseconds}ms');
    await _runGroup(suite, group, <Group>[], reporter);
    logHottie('runTests xx ${sw.elapsedMilliseconds}ms');
    reporter._onDone();
    logHottie('runTests ${sw.elapsedMilliseconds}ms');
  });

  return reporter;
}

/*
Declarer? _localDeclarer;
Declarer get _declarer {
  final declarer = Zone.current[#test.declarer] as Declarer?;
  if (declarer != null) {
    return declarer;
  }
  // If no declarer is defined, this test is being run via `flutter run -t test_file.dart`.
  if (_localDeclarer == null) {
    _localDeclarer = Declarer();
    Future<void>(() {
      Invoker.guard<Future<void>>(() async {
        final reporter = Reporter(); // disable color when run directly.
        // ignore: recursive_getters, this self-call is safe since it will just fetch the declarer instance
        final Group group = _declarer.build();
        final suite = Suite(group, SuitePlatform(Runtime.vm));
        await _runGroup(suite, group, <Group>[], reporter);
        reporter._onDone();
      });
    });
  }
  return _localDeclarer!;
}
*/

Future<void> _runGroup(
  Suite suiteConfig,
  Group group,
  List<Group> parents,
  Reporter reporter,
) async {
  parents.add(group);
  try {
    final bool skipGroup = group.metadata.skip;
    var setUpAllSucceeded = true;
    if (!skipGroup && group.setUpAll != null) {
      final LiveTest liveTest = group.setUpAll!.load(suiteConfig, groups: parents);
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
          final test = entry as Test;
          await _runLiveTest(suiteConfig, test.load(suiteConfig, groups: parents), reporter);
        }
      }
    }
    // Even if we're closed or setUpAll failed, we want to run all the
    // teardowns to ensure that any state is properly cleaned up.
    if (!skipGroup && group.tearDownAll != null) {
      final LiveTest liveTest = group.tearDownAll!.load(suiteConfig, groups: parents);
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
  final bool isSuccess = liveTest.state.result.isPassing;
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
  final LiveTest liveTest = skipped.load(suiteConfig);
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
