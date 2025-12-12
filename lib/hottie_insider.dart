import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

typedef TestMap = Map<String, void Function()>;
typedef OnComplete = void Function();
typedef TestMapFactory = TestMap Function(OnComplete);
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
  final completer = Completer<void>();
  final statusCompleter = Completer<String>();
  final entries = tests(completer.complete).entries.where((x) => allowed.contains(x.key) || x.key == 'tearDownAll').toList();

  if (entries.length == 1) {
    return 'No tests ran';
  }

  runZonedGuarded(
    () {
      for (final test in entries) {
        test.value();
      }
    },
    (error, stackTrace) {
      stdout.writeln(error);
      stdout.writeln(stackTrace);
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, text) {
        if (completer.isCompleted) {
          if (!statusCompleter.isCompleted) {
            statusCompleter.complete(text);
          } else {
            stdout.writeln(text);
          }
        } else {
          _sendEvent(_eventHottieUpdate, {'text': text});
        }
      },
    ),
  );

  await completer.future;
  return statusCompleter.future;
}

void _sendEvent(String name, Map<String, dynamic> params) {
  stdout.writeln(
    jsonEncode([
      {'event': name, 'params': params},
    ]),
  );
}
