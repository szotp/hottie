import 'package:flutter/foundation.dart';
import 'package:hottie/src/isolated_runner.dart';
import 'package:hottie/src/logger.dart';
import 'package:hottie/src/model.g.dart';
import 'package:hottie/src/widget.dart';

class TestingController extends ValueNotifier<TestGroupResults> {
  TestingController() : super(TestGroupResultsExtension.emptyResults()) {
    final _ = _isolate;
  }

  late final _isolate = IsolatedRunnerService((results) {
    value = results;
    logHottie('failed: ${results.failed.length} passed: ${results.passed.length}');
  })
    ..respawn();
}
