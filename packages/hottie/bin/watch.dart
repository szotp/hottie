// ignore_for_file: avoid_print user interaction

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:hottie/src/utils/logger.dart';
import 'package:hottie/src/watch.dart';

import 'generate.dart';

class WatchCommand extends Command<void> {
  @override
  String get description => 'Watch current directory for tests';
  @override
  String get name => 'watch';

  @override
  FutureOr<void>? run() async {
    final testPaths = findTestsInCurrentDirectory();
    final hottieUri = await generateMain(testPaths);
    logger.info('Generated $hottieUri');

    final process = await Process.start('flutter', [
      'run',
      hottieUri.toFilePath(),
      '-d',
      'flutter-tester',
      '--no-pub',
      '--device-connection',
      'attached',
      '--dart-define',
      'HOTTIE_WATCH=true',
    ]);

    process.stderr.listen(stderr.add);
    process.stdout.transform(utf8.decoder).transform(const LineSplitter()).forEach((line) {
      if (line.contains(progressPlaceholder)) {
        stdout.write(line.replaceFirst(progressPlaceholder, ansiReplaceLine));
      } else {
        stdout.writeln(line);
      }
    }).withLogging();
    stdin.listen(process.stdin.add);

    try {
      stdin.lineMode = false;
    } catch (_) {
      // in debug console
    }

    final watcher = watchDartFiles(['.']);
    await watcher.forEach((changedFile) {
      process.stdin.write('r');
    });
  }
}
