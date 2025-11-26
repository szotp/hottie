import 'dart:io';

import 'package:example/main.dart';
import 'package:flutter_test/flutter_test.dart';

const shouldFail = bool.fromEnvironment('shouldFail');

void main() {
  test('test add 1', () {
    expect(add(1, 2), 3);
  });

  test('test asserts', () {
    assert(!shouldFail);
  });

  test(
    'file access',
    () {
      final file = File('file.txt');
      final contents = file.readAsStringSync();
      expect(contents, 'test');
    },
    tags: ["File"],
  );
}
