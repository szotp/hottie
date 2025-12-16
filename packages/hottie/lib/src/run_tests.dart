// ignore_for_file: implementation_imports necessary for our use case

import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';

import '../hottie_insider.dart';
import 'mock_assets.dart';
import 'script_change.dart';
import 'spawn.dart';
import 'test_compat.dart';
import 'utils/logger.dart';

const Spawn<TestFiles, Files> spawnRunTests = Spawn(_runTests);

Future<Files> _runTests(Future<TestFiles> testsFuture) async {
  final binding = HottieBinding.instance;
  mockFlutterAssets();

  final saved = Directory.current;
  final tests = await testsFuture;
  final reporter = Reporter();
  for (final entry in tests) {
    if (binding.didHotReloadWhileTesting) {
      // hot reload is not supported, we have to quit asap to prevent crashes
      logger.warning('Hot reload detected. Exiting tests');
      Isolate.exit();
    }

    final uri = Uri.parse(entry.uriString);

    try {
      Directory.current = uri.packagePath;

      logger.info('TESTING: ${uri.relativePath}');
      goldenFileComparator = LocalFileComparator(uri);
      await runTests(entry.testMain, reporter).timeout(const Duration(seconds: 10));
    } catch (error, stackTrace) {
      print('ERROR: $error');
      print(stackTrace);
    }
  }
  Directory.current = saved;

  print('Failed: ${reporter.failed.length}. Passed: ${reporter.passed.length}');
  return const Files({});
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
