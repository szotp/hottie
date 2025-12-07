import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

typedef TestMap = Map<String, void Function()>;
typedef TestMapFactory = TestMap Function();
const String hottieExtensionName = 'ext.hottie.test';
const String hottieRegisteredEventName = 'hottie.registered';

Future<void> hottie(TestMapFactory tests) async {
  registerExtension(hottieExtensionName, (_, args) async {
    final allowed = (jsonDecode(args['paths']!) as List).toSet().cast<String>();
    final entries = tests().entries.where((x) => allowed.contains(x.key)).toList();

    for (final test in entries) {
      test.value();
    }

    return ServiceExtensionResponse.result('{}');
  });

  final isolateId = Service.getIsolateId(Isolate.current);
  stdout.writeln('[{"event":"$hottieRegisteredEventName","params":{"isolateId":"$isolateId"}}]');
}
