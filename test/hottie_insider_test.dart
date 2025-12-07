import 'dart:isolate';

import 'package:hottie/hottie_insider.dart';
import 'package:test/test.dart';

void main() {
  test('parsing success', () async {
    final ok = await _runIsolated();
    expect(ok, true);
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

    return runTests(map.entries, report: (_) {});
  });
}
