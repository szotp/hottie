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
typedef TestConfigurationFunc = RunTestsRequest Function(IsolateArguments);

Future<void> hottie(TestConfigurationFunc func) async {
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

  final request = func(IsolateArguments([], Files.empty, isInitialRun: true));
  if (request.tests.isNotEmpty) {
    failed = await spawnRunTests.compute(Future.value(request));
  }

  logger.info('Waiting for hot reload');
  await scriptChange.observe().forEach((changedTestsFuture) async {
    final future = changedTestsFuture.then((changedFiles) {
      logger.fine('Spawning for: ${changedFiles.describe()}');
      final arguments = IsolateArguments(failed, changedFiles);
      return func(arguments);
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

class IsolateArguments {
  IsolateArguments(this.failed, this.changedTests, {this.isInitialRun = false});

  final bool isInitialRun;
  final List<FailedTest> failed;
  final Files changedTests;
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
