// ignore_for_file: implementation_imports necessary for our use case
// ignore_for_file: always_use_package_imports necessary for our use case

import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_core/src/direct_run.dart';

import 'src/mock_assets.dart';
import 'src/script_change.dart';
import 'src/spawn.dart';
import 'src/utils/logger.dart';

typedef TestFiles = Iterable<TestFile>;
typedef TestConfigurationFunc = TestFiles Function(IsolateArguments);

const Spawn<TestFiles, Files> _spawn = Spawn(_runTests);

Future<void> hottie(TestConfigurationFunc func) async {
  if (await _spawn.runIfIsolate()) {
    return;
  }

  final vm = await vmServiceConnect();

  if (vm == null) {
    print('VM not detected. Exiting.');
    return;
  }

  final scriptChange = ScriptChangeChecker(vm, Service.getIsolateId(Isolate.current)!);
  var failed = Files.empty;

  logger.info('Waiting for hot reload');
  await scriptChange.observe().forEach((changedTestsFuture) async {
    final future = changedTestsFuture.then((changedFiles) {
      logger.info('Spawning for: ${changedFiles.describe()}');

      // ignore: unused_local_variable xx
      final arguments = IsolateArguments(failed, changedFiles);
      return func(arguments);
    });

    logger.fine('Spawning...');
    failed = await _spawn.compute(_runTests, future);
    logger.fine('Tests finished');
  });
}

extension type const PackageName(String name) {}

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
  IsolateArguments(this.failed, this.changedTests);

  static IsolateArguments? decode(String encoded) {
    final parts = encoded.split('|');

    if (parts.length != 2) {
      return null;
    }

    return IsolateArguments(
      Files.decode(parts[0]),
      Files.decode(parts[1]),
    );
  }

  final Files failed;
  final Files changedTests;

  String encode() {
    return '${failed.encode()}|${changedTests.encode()}';
  }
}

Future<Files> _runTests(Future<TestFiles> testsFuture) async {
  final binding = HottieBinding.instance;
  mockFlutterAssets();

  final passed = <String>[];
  final failed = <String>[];

  final saved = Directory.current;
  final tests = await testsFuture;
  for (final entry in tests) {
    if (binding.didHotReloadWhileTesting) {
      // hot reload is not supported, we have to quit asap to prevent crashes
      logger.warning('Hot reload detected. Exiting tests');
      Isolate.exit();
    }

    var passedTest = false;
    final uri = Uri.parse(entry.uriString);

    try {
      Directory.current = uri.packagePath;

      logger.info('TESTING: ${uri.relativePath}');
      goldenFileComparator = LocalFileComparator(uri);
      passedTest = await directRunTests(
        entry.testMain,
        //reporterFactory: (engine) => GithubReporter.watch(engine, stdout, printPlatform: false, printPath: true),
      ).timeout(const Duration(seconds: 10));
    } catch (error, stackTrace) {
      print('ERROR: $error');
      print(stackTrace);
    }

    if (passedTest) {
      passed.add(uri.toString());
    } else {
      failed.add(uri.toString());
    }
  }
  Directory.current = saved;

  print('Failed: ${failed.length}. Passed: ${passed.length}');
  return Files(failed.toSet());
}

extension on Uri {
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
