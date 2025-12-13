// ignore_for_file: implementation_imports necessary for our use case
// ignore_for_file: always_use_package_imports necessary for our use case

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_core/src/direct_run.dart';
import 'package:vm_service/vm_service.dart';

import 'src/ffi.dart';
import 'src/mock_assets.dart';
import 'src/script_change.dart';

typedef TestMap = Map<String, void Function()>;
typedef TestMapFactory = TestMap Function();

Future<void> hottie(TestMapFactory tests, {bool runImmediately = false}) async {
  final vm = await vmServiceConnect();

  if (vm == null) {
    print('VM not detected. Running tests');
    await runTests(tests);
    return;
  }

  await vm.streamListen(EventStreams.kIsolate);
  await vm.onIsolateEvent.forEach((event) async {
    if (event.kind == EventKind.kIsolateReload) {
      spawn('hottieIsolated', '');
    }
  });
}

Future<void> runTests(TestMapFactory tests, {Set<String>? allowed}) async {
  final entries = tests().entries.where((x) => allowed?.remove(x.key) ?? true).toList();
  final missing = allowed?.toSet() ?? {};
  missing.removeAll(entries.map((x) => x.key));
  assert(missing.isEmpty, 'Tests not found: $missing.\n AVAILABLE TESTS: ${tests().keys.toList()}');

  AutomatedTestWidgetsFlutterBinding.ensureInitialized();
  mockFlutterAssets();

  final passed = <Uri>[];
  final failed = <Uri>[];

  for (final entry in entries) {
    var passedTest = false;
    final uri = Uri.file(entry.key);

    try {
      Directory.current = uri.packagePath;

      print('TESTING: ${uri.relativePath}');
      goldenFileComparator = LocalFileComparator(uri);
      passedTest = await directRunTests(entry.value).timeout(const Duration(seconds: 10));
      //reporterFactory: (engine) => FailuresOnlyReporter.watch(engine, stdout, color: true, printPlatform: false, printPath: true));
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

  print('Failed: ${failed.length}. Passed: ${passed.length}');
  for (final failed in failed) {
    print(failed);
  }
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
    return Uri(pathSegments: segments, scheme: 'file').toFilePath();
  }
}
