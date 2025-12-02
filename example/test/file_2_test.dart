import 'package:example/calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('2', () {
    test('simple 1', () async {
      expect(1, 1);
    });

    test('simple 2', () async {
      expect(1, 5);
    });

    test('simple 3', () async {
      expect(1, 2);
    });

    test('simple 4', () async {
      expect(calculate(0, 1), 1);
    });
  });
}
