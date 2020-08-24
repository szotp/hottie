import 'dart:io';

import 'package:example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('test add 1', () async {
    expect(add(1, 2), 3);
  });

  test(
    'file access',
    () async {
      final file = File('file.txt');
      final contents = file.readAsStringSync();
      expect(contents, 'test');
    },
    tags: ["File"],
  );
}
