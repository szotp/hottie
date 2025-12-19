// ignore_for_file: implementation_imports necessary for our use case
// ignore_for_file: always_use_package_imports necessary for our use case

import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';

import 'src/run_tests.dart';
import 'src/script_change.dart';
import 'src/test_compat.dart';
import 'src/utils/logger.dart';

export 'src/run_tests.dart' show RunTestsRequest;

typedef TestFiles = Iterable<TestFile>;
typedef TestConfigurationFunc = void Function(HottieContext, RunTestsRequest);

Future<void> hottie(TestConfigurationFunc func, List<TestFile> allTests) async {
  if (await spawnRunTests.runIfIsolate()) {
    return;
  }

  final vm = await vmServiceConnect();

  if (vm == null) {
    logger.warning('VM not detected. Exiting.');
    return;
  }

  final scriptChange = ScriptChangeChecker(vm, Service.getIsolateId(Isolate.current)!);
  var failed = <FailedTest>[];

  final request = RunTestsRequest();
  func(HottieContext([], [], allTests, isInitialRun: true), request);
  if (request.tests.isNotEmpty) {
    failed = await spawnRunTests.compute(Future.value(request));
  }

  logger.info('Waiting for hot reload');
  await scriptChange.observe().forEach((changedTestsFuture) async {
    final future = changedTestsFuture.then((changedFiles) {
      logger.fine('Spawning for: ${changedFiles.describe()}');
      final request = RunTestsRequest();
      final arguments = HottieContext(failed, allTests.where(changedFiles.contains).toList(), allTests);
      func(arguments, request);
      return request;
    });

    logger.fine('Spawning...');
    failed = await spawnRunTests.compute(future);
    logger.fine('Tests finished');
  });
}

typedef TestMain = void Function();

class TestFile {
  const TestFile(this.uriString, this.testMain);
  final String uriString;
  final TestMain testMain;
}

class HottieBinding extends AutomatedTestWidgetsFlutterBinding {
  bool didHotReloadWhileTesting = false;

  @override
  Future<void> reassembleApplication() async {
    didHotReloadWhileTesting = true;
  }

  static final instance = HottieBinding();
}

class HottieContext {
  HottieContext(this.failed, this.changedTests, this.allTests, {this.isInitialRun = false});

  /// Is running for the first time (not caused by hot reload)
  final bool isInitialRun;

  /// Tests which failed in previous run
  final List<FailedTest> failed;

  /// Tests that changed since in most recent hot reload, determined by vm_service loaded scripts scan
  final List<TestFile> changedTests;

  /// All known test files
  final List<TestFile> allTests;
}

extension FilesExtension on Files {
  bool contains(TestFile file) => uris.contains(file.uriString);
  bool containsNot(TestFile file) => !uris.contains(file.uriString);
}

extension TestListExtensions on List<TestFile> {
  void keepOnly(bool Function(TestFile) filter) {
    removeWhere((x) => !filter(x));
  }
}

extension TestFileExtension on TestFile {
  String get packageName {
    final segments = Uri.parse(uriString).pathSegments;
    final index = segments.lastIndexOf('test');
    return segments[index - 1];
  }

  Uri get uri => Uri.parse(uriString);
}

extension UriExtension on Uri {
  String get relativePath {
    final current = Directory.current.path;
    if (path.startsWith(current)) {
      return path.substring(current.length + 1);
    }
    return path;
  }

  String get packagePath {
    final segments = pathSegments.sublist(0, pathSegments.indexOf('test'));
    final filePath = Uri(pathSegments: segments, scheme: 'file').toFilePath();
    return filePath;
  }
}
