// ignore_for_file: implementation_imports necessary for our use case

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:test_core/src/direct_run.dart';

typedef TestMap = Map<String, void Function()>; //
typedef TestMapFactory = TestMap Function();
const String _hottieExtensionName = 'ext.hottie.test';
const String _eventHottieRegistered = 'hottie.registered';
const String _eventHottieUpdate = 'hottie.update';

Future<void> hottie(TestMapFactory tests) async {
  registerExtension(_hottieExtensionName, (_, args) async {
    final allowed = (jsonDecode(args['paths']!) as List).toSet().cast<String>();
    final status = await runTests(tests, allowed);
    return ServiceExtensionResponse.result(jsonEncode({'status': status}));
  });

  final isolateId = Service.getIsolateId(Isolate.current);
  _sendEvent(_eventHottieRegistered, {'isolateId': isolateId});
}

Future<String> runTests(TestMapFactory tests, Set<String> allowed) async {
  final entries = tests().entries.where((x) => allowed.contains(x.key) || x.key == 'tearDownAll').toList();

  final ok = await directRunTests(() {
    for (final entry in entries) {
      entry.value();
    }
  });

  return ok.toString();
}

void _sendEvent(String name, Map<String, dynamic> params) {
  stdout.writeln(
    jsonEncode([
      {'event': name, 'params': params},
    ]),
  );
}
