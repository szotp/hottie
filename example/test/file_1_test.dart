import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const value = 1;

void main() {
  group('group 1', () {
    testWidgets('testWidgets 1', (tester) async {
      const text = Text('Hello');
      await tester.pumpWidget(const Directionality(textDirection: TextDirection.ltr, child: text));
      final node = tester.getSemantics(find.byWidget(text));
      expect(node.label, equals('Hello'));
    });
  });
}
