#!/usr/bin/env dart
// ignore_for_file: avoid_print user interaction

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:hottie/src/utils/logger.dart';

import 'generate_main.dart';

const String version = '0.0.2';

void addGlobalOptions(ArgParser parser) {
  parser
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Show additional command output. Shorthand for --loggerLevel ALL',
    )
    ..addFlag('version', negatable: false, help: 'Print the tool version.');
}

Future<void> main(List<String> arguments) async {
  await _CommandRunner().run(arguments);
}

class _CommandRunner extends CommandRunner<void> {
  _CommandRunner() : super('hottie', 'Test hot-reloader for flutter') {
    addGlobalOptions(argParser);
    addCommand(_RunCommand());
  }

  @override
  Future<void> runCommand(ArgResults args) async {
    if (args.flag('version')) {
      print('hottie $version');
      return;
    }

    return super.runCommand(args);
  }
}

class _RunCommand extends Command<void> {
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
    ]);

    process.stderr.listen(stderr.add);
    process.stdout.listen(stdout.add);
    stdin.listen(process.stdin.add);

    try {
      stdin.lineMode = false;
    } catch (_) {
      // in debug console
    }
  }
}
