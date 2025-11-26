import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty widgets', (x) async {});

  test('test add 2', () {
    expect(add(1, 1), 2);
  });

  testWidgets('find', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ListView(
          children: const [
            Text('0'),
            Text('0'),
            Text('1'),
          ],
        ),
      ),
    );

    expect(find.text('0'), findsNWidgets(2));
  });
}
