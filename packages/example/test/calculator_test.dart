import 'package:example/calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('add', () {
    expect(calculate(1, 2), 3);
  });
}
