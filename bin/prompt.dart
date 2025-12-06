import 'dart:io';

import 'package:hottie/src/utils/logger.dart';
import 'package:hottie/src/watch.dart';

Future<void> main() async {
  hotReloadAutomatically(run).withLogging();
}

Stream<void> run() async* {
  for (var i = 0; i <= 100; i++) {
    stdout.write('\r$i%');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    yield null;
  }
  stdout.writeln(); // Add newline at the end
}
