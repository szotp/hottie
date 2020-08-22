import 'package:flutter/widgets.dart';

import 'main.dart' as m;
import 'package:hottie/hottie.dart';
import 'test/test.dart' as t;

void main() {
  runApp(
    TestRunner(main: t.main, child: m.MyApp()),
  );
}
