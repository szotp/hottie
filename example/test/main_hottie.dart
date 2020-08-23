import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hottie/hottie.dart';
import 'package:example/main.dart' as m;

import 'standard_test.dart' as t1;
import 'widgets_test.dart' as t2;

Future<void> main() async {
  runApp(
    TestRunner(main: testAll, child: m.MyApp()),
  );
}

@pragma('vm:entry-point')
void hottie() => hottieInner();

void testAll() {
  t1.main();
  t2.main();
}
