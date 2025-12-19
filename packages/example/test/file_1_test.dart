import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const value = 2;

void main() {
  test('empty', () {});
  test('simplest', () {
    expect(2, value);
  });

  testWidgets('testWidgets', (tester) async {
    const text = Text('Hello');
    await tester.pumpWidget(const Directionality(textDirection: TextDirection.ltr, child: text));
    final node = tester.getSemantics(find.byWidget(text));
    expect(node.label, equals('Hello'));
  });

  testWidgets(
    'testWidgets fail',
    (tester) async {
      const text = Text('Hello');
      await tester.pumpWidget(const Directionality(textDirection: TextDirection.ltr, child: text));
      final node = tester.getSemantics(find.byWidget(text));
      expect(node.label, equals('Hello world!'));
    },
    skip: false,
  );

  test('async', () async {
    await Future<void>.delayed(const Duration(milliseconds: 1));
    expect(1, 1);
  });

  test(
    'async failing',
    () async {
      await Future<void>.delayed(const Duration(milliseconds: 1));
      throw TestFailure('fail!');
    },
    skip: true,
  );

  testWidgets(
    'await from testWidget',
    (tester) async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1)));
    },
  );
}
