// ignore_for_file: implementation_imports necessary for our use case
// ignore_for_file: always_use_package_imports necessary for our use case

import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_core/src/direct_run.dart';
import 'package:test_core/src/runner/reporter/github.dart';
import 'package:vm_service/vm_service.dart';

import 'src/ffi.dart';
import 'src/mock_assets.dart';
import 'src/script_change.dart';
import 'src/utils/logger.dart';

typedef TestMain = void Function();
typedef TestMap = List<TestFile>;

Files startResultsReceiver() {
  final failed = Files({});

  final resultsPort = ReceivePort();
  IsolateNameServer.removePortNameMapping('hottie.resultsPort');
  IsolateNameServer.registerPortWithName(resultsPort.sendPort, 'hottie.resultsPort');
  resultsPort.forEach((message) {
    failed.uris.clear();
    failed.uris.addAll(Files.decode(message as String).uris);
    for (final file in failed!.uris) {
      print(file);
    }
  }).withLogging();
  return failed;
}

extension type PackageName(String name) {}

final class TestFile {
  const TestFile(this.uriString, this.testMain);
  final String uriString;
  final TestMain testMain;
}

Future<void> mainWatch({bool runImmediately = false}) async {
  final vm = await vmServiceConnect();

  if (vm == null) {
    print('VM not detected. Exiting.');
    return;
  }

  final failed = startResultsReceiver();

  if (runImmediately) {
    spawn('hottieIsolated', '');
  }

  await vm.streamListen(EventStreams.kIsolate);
  logger.info('Waiting for hot reload');
  await vm.onIsolateEvent.forEach((event) async {
    if (event.kind == EventKind.kIsolateReload) {
      logger.info('Spawning');
      spawn('hottieIsolated', failed?.encode() ?? '');
    }
  });
}

Future<void> mainRunTests(TestMap tests, {Set<TestFile>? allowed, Set<TestFile>? skip}) async {
  final entries = tests.where((x) {
    if (skip?.contains(x) ?? false) {
      return false;
    }
    return allowed?.contains(x) ?? true;
  }).toList();
  AutomatedTestWidgetsFlutterBinding.ensureInitialized();
  mockFlutterAssets();

  final passed = <Uri>[];
  final failed = <Uri>[];

  final saved = Directory.current;
  for (final entry in entries) {
    var passedTest = false;
    final uri = Uri.parse(entry.uriString);

    try {
      Directory.current = uri.packagePath;

      print('TESTING: ${uri.relativePath}');
      goldenFileComparator = LocalFileComparator(uri);
      passedTest = await directRunTests(
        entry.testMain,
        reporterFactory: (engine) => GithubReporter.watch(engine, stdout, printPlatform: false, printPath: true),
      ).timeout(const Duration(seconds: 10));
    } catch (error, stackTrace) {
      print(error);
      print(stackTrace);
    }

    if (passedTest) {
      passed.add(uri);
    } else {
      failed.add(uri);
    }
  }
  Directory.current = saved;

  print('Failed: ${failed.length}. Passed: ${passed.length}');
  IsolateNameServer.lookupPortByName('hottie.resultsPort')?.send(Files(failed.toSet()).encode());
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
