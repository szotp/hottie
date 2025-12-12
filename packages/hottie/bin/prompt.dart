import 'dart:io';

import 'package:hottie/src/utils/logger.dart';
import 'package:hottie/src/watch.dart';

Future<void> main() async {
  hotReloadAutomatically(run).withLogging();
}

Stream<void> run() async* {
  // Move cursor up and clear lines
  const moveUp = '\x1B[1A'; // Move cursor up 1 line
  const clearLine = '\x1B[2K'; // Clear entire line

  for (var i = 0; i <= 100; i++) {
    if (i > 0) {
      // Move up to overwrite previous lines
      stdout.write(moveUp + moveUp);
    }

    // Write multiple lines of progress
    stdout.write('${clearLine}Progress: $i%\n');
    stdout.write('${clearLine}Status: ${i < 100 ? "Running..." : "Complete!"}');

    await Future<void>.delayed(const Duration(milliseconds: 100));
    yield null;
  }
  stdout.writeln(); // Add newline at the end
}
