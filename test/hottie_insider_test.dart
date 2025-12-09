import 'dart:isolate';

import 'package:hottie/hottie_insider.dart';
import 'package:hottie/src/daemon.dart';
import 'package:test/test.dart';

void main() {
  test('parsing success', () async {
    final ok = await _runIsolated();
    expect(ok, false);
  });

  test('parsing failure', () async {
    final ok = await _runIsolated(expected: 2);
    expect(ok, false);
  });

  test('parsing skipped', () async {
    final ok = await _runIsolated(skip: true);
    expect(ok, true);
  });

  test('parsing empty', () async {
    final ok = await _runIsolated(declare: false);
    expect(ok, true);
  });
}

Future<bool> _runIsolated({int expected = 1, bool? skip, bool declare = true}) {
  return Isolate.run(() async {
    final map = {
      'file_test.dart': () {
        if (declare) {
          test(
            'inner',
            () {
              expect(1, expected);
            },
            skip: skip,
          );
        }
      },
    };

    final collector = _Collector();
    final lastMessage = await runTests(map.entries, report: collector.add);
    return !lastMessage.contains('failed');
  });
}

class _Collector {
  final List<String> lines = [];

  void add(String eventJson) {
    final event = DaemonMessage.parse(eventJson)! as DaemonEvent;
    final line = event.params['line'] as String;
    lines.add(line);
  }
}
