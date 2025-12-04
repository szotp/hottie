import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'file_1_test.dart' as f1;
import 'file_2_test.dart' as f2;

void tests() {
  f1.main();
  f2.main();
}

// in VSCode, pressing F5 should run this
// can be run from terminal, but won't reload automatically
// flutter run test/runner.dart -d flutter-tester
void main() {
  final isolateId = Service.getIsolateId(Isolate.current);
  registerExtension('ext.hottie.test', (_, args) async {
    tests();
    return ServiceExtensionResponse.result('{}');
  });
  final event = {
    'event': 'hottie.registered',
    'params': {
      'isolateId': isolateId!,
      'name': 'ext.hottie.test',
    },
  };
  stdout.writeln(jsonEncode([event]));
}
