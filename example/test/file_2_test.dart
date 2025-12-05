import 'package:example/calculator.dart';
import 'package:test/test.dart';

const value = 1;

void main() {
  group('2', () {
    test('simple 1', () async {
      expect(1, value);
    });

    test('simple 2', () async {
      expect(1, 1);
    });

    test('simple 3', () async {
      expect(1, 1);
    });

    test('simple 4', () async {
      expect(calculate(0, 1), 1);
    });
  });
}
