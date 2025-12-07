// ignore_for_file: avoid_print necessary for communication with hottie

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';

typedef TestMap = Map<String, void Function()>;
typedef TestMapFactory = TestMap Function();
const String hottieExtensionName = 'ext.hottie.test';
const String hottieRegisteredEventName = 'hottie.registered';
const String hottieReportEventName = 'hottie.report';

Future<void> hottie(TestMapFactory tests) async {
  registerExtension(hottieExtensionName, (_, args) async {
    final allowed = (jsonDecode(args['paths']!) as List).toSet().cast<String>();
    final entries = tests().entries.where((x) => allowed.contains(x.key));
    final ok = await runTests(entries, report: stdout.writeln);
    return ServiceExtensionResponse.result('{"result":$ok}');
  });

  final isolateId = Service.getIsolateId(Isolate.current);
  print('[{"event":"$hottieRegisteredEventName","params":{"isolateId":"$isolateId"}}]');
}

Future<bool> runTests(Iterable<MapEntry<String, void Function()>> entries, {required void Function(String) report}) async {
  final completer = Completer<bool>();
  final value = await runZonedGuarded(
    () async {
      for (final test in entries) {
        group(test.key, test.value);
      }
      tearDownAll(() {});
      return completer.future;
    },
    (error, stackTrace) {},
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        final event = {
          'event': 'hottie.report',
          'params': {
            'line': line,
          },
        };
        report(jsonEncode([event]));

        if (line.contains('All tests passed!') || line.contains('All tests skipped.') || line.contains('No tests ran.')) {
          completer.complete(true);
        } else if (line.contains('Some tests failed.')) {
          completer.complete(false);
        }
      },
    ),
  );

  return value ?? false;
}
