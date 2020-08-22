import 'package:flutter/widgets.dart';

import 'main.dart' as m;
import 'package:hottie/hottie.dart';
import 'tests/widget_test.dart' as tests;

/// hottie must be prepared in separate main file that is not used to prepare builds
/// otherwise we would have test dependencies inside production app
void main() {
  runApp(
    TestRunner(
      main: tests.main,
      child: m.MyApp(),
    ),
  );
}
