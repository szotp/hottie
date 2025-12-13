// ignore_for_file: implementation_imports necessary for our use case,
// ignore_for_file: unused_import

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
// ignore: depend_on_referenced_packages xx
import 'package:flutter_test/flutter_test.dart';
import 'package:test_core/src/direct_run.dart';
import 'package:test_core/src/runner/reporter/failures_only.dart';

typedef TestMap = Map<String, void Function()>; //
typedef TestMapFactory = TestMap Function();
const String _hottieExtensionName = 'ext.hottie.test';
const String _eventHottieRegistered = 'hottie.registered';
const String _eventHottieUpdate = 'hottie.update';

Future<void> hottie(TestMapFactory tests) async {
  registerExtension(_hottieExtensionName, (_, args) async {
    final allowed = (jsonDecode(args['paths']!) as List).toSet().cast<String>();
    assert(allowed.isNotEmpty, 'Nothing to run');
    final assetFolderPath = args['assets']!;
    final status = await runTests(tests, allowed, assetFolderPath);
    return ServiceExtensionResponse.result(jsonEncode({'status': status}));
  });

  final isolateId = Service.getIsolateId(Isolate.current);
  _sendEvent(_eventHottieRegistered, {'isolateId': isolateId});
}

Future<String> runTests(TestMapFactory tests, Set<String> allowed, String assetFolderPath) async {
  final entries = tests().entries.where((x) => allowed.remove(x.key) || x.key == 'tearDownAll').toList();

  final missing = allowed.toSet();
  missing.removeAll(entries.map((x) => x.key));

  assert(missing.isEmpty, 'Tests not found: $missing.\n AVAILABLE TESTS: ${tests().keys.toList()}');

  var ok = true;

  AutomatedTestWidgetsFlutterBinding.ensureInitialized();

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
    'flutter/assets',
    (ByteData? message) async {
      final completer = Completer<ByteData?>();
      PlatformDispatcher.instance.sendPlatformMessage('flutter/assets', message, completer.complete);
      return completer.future;
    },
  );

  for (final entry in entries) {
    final uri = Uri.file(entry.key);
    final components = uri.pathSegments.toList();
    components.sublist(0, components.indexOf('test'));
    components.add('build/unit_test_assets');

    print('TESTING: ${entry.key}');
    goldenFileComparator = LocalFileComparator(uri);
    final passed = await directRunTests(entry.value);
    //reporterFactory: (engine) => FailuresOnlyReporter.watch(engine, stdout, color: true, printPlatform: false, printPath: true));
    ok = ok && passed;
  }

  return ok.toString();
}

void _sendEvent(String name, Map<String, dynamic> params) {
  stdout.writeln(
    jsonEncode([
      {'event': name, 'params': params},
    ]),
  );
}

String pathJoin(String a, String b) => '$a/$b';
