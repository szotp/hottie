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
    final lastLine = await runTests(entries, report: stdout.writeln);
    final json = {
      'result': lastLine,
    };
    return ServiceExtensionResponse.result(jsonEncode(json));
  });

  final isolateId = Service.getIsolateId(Isolate.current);
  print('[{"event":"$hottieRegisteredEventName","params":{"isolateId":"$isolateId"}}]');
}

Future<String> runTests(Iterable<MapEntry<String, void Function()>> entries, {required void Function(String) report}) async {
  final completer1 = Completer<void>();
  final completer2 = Completer<String>();
  await runZonedGuarded(
    () async {
      for (final test in entries) {
        group(test.key, test.value);
      }
      tearDownAll(completer1.complete);
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

        if (completer1.isCompleted) {
          if (!completer2.isCompleted) {
            completer2.complete(line.trim());
          }
        } else {
          report(jsonEncode([event]));
        }
      },
    ),
  );

  return completer2.future;
}
