import 'package:example/main.dart' as m;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hottie/hottie.dart';

import 'calculator_test.dart' as t3;
import 'standard_test.dart' as t1;
import 'widgets_test.dart' as t2;

Future<void> main() async {
  runApp(
    TestRunner(main: () {}, child: m.MyApp()),
  );
}

@pragma('vm:entry-point')
void hottie(List<String> args) => runInsideIsolate(args, {
      'calculator_test.dart': t1.main,
      'standard_test.dart': t2.main,
      'widgets_test.dart': t3.main,
    });
