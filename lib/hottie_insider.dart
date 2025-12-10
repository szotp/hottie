// ignore_for_file: avoid_print necessary for communication with hottie

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

// ignore: depend_on_referenced_packages x
import 'package:flutter_test/flutter_test.dart';

typedef TestMap = Map<String, void Function()>;
typedef TestMapFactory = TestMap Function();
const String _hottieExtensionName = 'ext.hottie.test';
const String _hottieRegisteredEventName = 'hottie.registered';
const String _hottieReportEventName = 'hottie.report';

Future<void> hottie(TestMapFactory tests) async {
  registerExtension(_hottieExtensionName, (_, args) async {
    final allowed = (jsonDecode(args['paths']!) as List).toSet().cast<String>();

    final entries = tests().entries.where((x) => allowed.contains(x.key));

    AutomatedTestWidgetsFlutterBinding.ensureInitialized();

    final lastLine = await runTests(entries, report: stdout.writeln);
    final json = {
      'result': lastLine,
    };
    return ServiceExtensionResponse.result(jsonEncode(json));
  });

  final isolateId = Service.getIsolateId(Isolate.current);
  print('[{"event":"$_hottieRegisteredEventName","params":{"isolateId":"$isolateId"}}]');
}

Future<String> runTests(Iterable<MapEntry<String, void Function()>> entries, {required void Function(String) report}) async {
  final completer1 = Completer<void>();
  final completer2 = Completer<String>();
  await runZonedGuarded(
    () async {
      for (final test in entries) {
        print('XXX ${test.key} XXXX');
        group(test.key, test.value);
      }
      tearDownAll(completer1.complete);
    },
    (error, stackTrace) {
      stdout.writeln(error);
      stdout.writeln(stackTrace);
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        final trimmed = line.substring(0, line.length - 1);

        if (completer1.isCompleted) {
          if (!completer2.isCompleted) {
            completer2.complete(trimmed);
          }
        } else {
          final event = {
            'event': _hottieReportEventName,
            'params': {
              'line': trimmed,
            },
          };
          report(jsonEncode([event]));
        }
      },
    ),
  );

  return completer2.future;
}
