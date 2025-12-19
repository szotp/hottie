#!/usr/bin/env dart
// ignore_for_file: avoid_print user interaction

import 'dart:async';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:hottie/src/utils/logger.dart';

import 'generate.dart';
import 'watch.dart';

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
  printer.appendLocation = false;
  await _CommandRunner().run(arguments);
}

class _CommandRunner extends CommandRunner<void> {
  _CommandRunner() : super('hottie', 'Test hot-reloader for flutter') {
    addGlobalOptions(argParser);
    addCommand(WatchCommand());
    addCommand(GenerateCommand());
  }

  @override
  Future<void> runCommand(ArgResults args) async {
    if (args.flag('version')) {
      logger.info('hottie $version');
      return;
    }

    return super.runCommand(args);
  }
}
