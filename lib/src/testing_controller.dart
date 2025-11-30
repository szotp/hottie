import 'package:flutter/cupertino.dart';
import 'package:hottie/src/declarer.dart';
import 'package:hottie/src/dependency_finder.dart';
import 'package:hottie/src/isolated_runner.dart';
import 'package:hottie/src/logger.dart';
import 'package:hottie/src/model.g.dart';
import 'package:hottie/src/widget.dart';

class TestingController extends ValueNotifier<TestGroupResults> {
  final TestMain testMain;

  final _observer = ScriptChangeObserver();

  TestingController(this.testMain) : super(TestGroupResultsExtension.emptyResults());

  late final _isolate = IsolatedRunnerService((results) {
    value = results;
    logHottie('failed: ${results.failed.length} passed: ${results.passed.length}');
  });

  Future<void> retest() async {
    final libraries = await _observer.checkLibraries();

    logHottie('retest: $libraries');

    await _isolate.execute(testMain);
  }
}
