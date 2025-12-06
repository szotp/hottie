#!/usr/bin/env dart
// ignore_for_file: avoid_print user interaction

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:hottie/src/frontend.dart';
import 'package:hottie/src/script_change.dart';
import 'package:hottie/src/utils/logger.dart';
import 'package:logging/logging.dart';

const String version = '0.0.2';

void addGlobalOptions(ArgParser parser) {
  parser
    ..addOption('loggerLevel', allowed: Level.LEVELS.map((x) => x.name))
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

    final loggerLevel = args.option('loggerLevel');
    if (loggerLevel != null) {
      logger.level = Level.LEVELS.firstWhere((x) => x.name == loggerLevel);
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
    final args = argResults!;

    final files = args.rest;
    for (final file in files) {
      if (!File(file).existsSync()) {
        logger.shout('$file does not exist');
        exit(-1);
      }
    }

    final frontend = HottieFrontendNew();
    await frontend.run(RelativePaths(files.toSet()));
  }
}
