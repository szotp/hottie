import 'package:flutter/widgets.dart';
import 'package:hottie/src/runner.dart';

import 'file_1_test.dart' as f1;
import 'file_2_test.dart' as f2;

// in VSCode, pressing F5 should run this
// can be run from terminal, but won't reload automatically
// flutter run test/runner.dart -d flutter-tester
void main() {
  runHottie();
  runApp(const Placeholder());
}

@pragma('vm:entry-point')
void hottie() => runHottieIsolate({
      'file_1_test.dart': f1.main,
      'file_2_test.dart': f2.main,
    });
