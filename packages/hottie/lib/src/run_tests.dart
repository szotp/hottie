// ignore_for_file: implementation_imports necessary for our use case

import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';

import '../hottie_insider.dart';
import 'mock_assets.dart';
import 'spawn.dart';
import 'test_compat.dart';
import 'utils/logger.dart';

const Spawn<RunTestsRequest, List<FailedTest>> spawnRunTests = Spawn(_runTests);

class RunTestsRequest {
  /// Files that should be tested
  List<TestFile> tests = [];

  bool logging = true;

  Duration timeout = const Duration(minutes: 1);

  List<RunTestsRequest> split(int shards) {
    final results = List.generate(shards, (x) => RunTestsRequest()..logging = logging);

    for (final (i, test) in tests.indexed) {
      results[i % shards].tests.add(test);
    }

    return results;
  }

  @override
  String toString() {
    if (tests.length > 5) {
      return '${tests.length} files';
    }

    return tests.join(', ');
  }
}

Future<List<FailedTest>> _runTests(Future<RunTestsRequest> testsFuture) async {
  final binding = HottieBinding.instance;
  mockFlutterAssets();

  final saved = Directory.current;
  final request = await testsFuture;
  final tests = request.tests;
  if (tests.isEmpty) {
    return [];
  }

  final reporter = Reporter();
  stdout.writeln();
  logger.info('TESTING STARTED for $request.');
  for (final entry in tests) {
    if (binding.didHotReloadWhileTesting) {
      // hot reload is not supported, we have to quit asap to prevent crashes
      logger.warning('Hot reload detected. Exiting tests');
      Isolate.exit();
    }

    final uri = Uri.parse(entry.uriString);

    try {
      Directory.current = uri.packagePath;

      logger.fine('TESTING: ${uri.relativePath}');
      goldenFileComparator = LocalFileComparator(uri);
      reporter.currentFile = entry;
      await runTests(entry.testMain, reporter);
    } catch (error, stackTrace) {
      logger.severe(error, stackTrace);
    }
  }
  Directory.current = saved;

  stdout.writeln();

  for (final test in reporter.failed) {
    final lines = [
      '${test.file.uri.relativePath} ${test.name}',
      ...test.errors,
    ];
    logger.warning(lines.join('\n'));
  }
  logger.info('TESTING FINISHED. Failed: ${reporter.failed.length}. Passed: ${reporter.passed.length}.');
  return reporter.failed;
}
