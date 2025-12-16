// ignore_for_file: implementation_imports necessary for our use case
// ignore_for_file: always_use_package_imports necessary for our use case

import 'dart:developer';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';

import 'src/run_tests.dart';
import 'src/script_change.dart';
import 'src/utils/logger.dart';

typedef TestFiles = Iterable<TestFile>;
typedef TestConfigurationFunc = TestFiles Function(IsolateArguments);

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
  var failed = Files.empty;

  final initialTests = func(IsolateArguments(Files.empty, Files.empty, isInitialRun: true)).toList();
  if (initialTests.isNotEmpty) {
    await spawnRunTests.compute(Future.value(initialTests.toList()));
  }

  logger.info('Waiting for hot reload');
  await scriptChange.observe().forEach((changedTestsFuture) async {
    final future = changedTestsFuture.then((changedFiles) {
      logger.info('Spawning for: ${changedFiles.describe()}');
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
  final Files failed;
  final Files changedTests;

  String encode() {
    return '${failed.encode()}|${changedTests.encode()}';
  }
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
}
