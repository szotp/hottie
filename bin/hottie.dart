#!/usr/bin/env dart
// ignore_for_file: avoid_print - printing to user

import 'dart:io';

import 'package:args/args.dart';
import 'package:hottie/src/frontend.dart';
import 'package:hottie/src/script_change.dart';
import 'package:hottie/src/utils/logger.dart';
import 'package:logging/logging.dart';

const String version = '0.0.2';

ArgParser buildParser() {
  final root = ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this usage information.',
    )
    ..addOption('loggerLevel', allowed: Level.LEVELS.map((x) => x.name))
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Show additional command output. Shorthand for --loggerLevel ALL',
    )
    ..addFlag('version', negatable: false, help: 'Print the tool version.');

  root.addCommand('run');

  return root;
}

void printUsage(ArgParser argParser) {
  print('Usage: dart run hottie <flags> <command> [arguments]');
  print(argParser.usage);
}

Future<void> main(List<String> arguments) async {
  final argParser = buildParser();
  try {
    final results = argParser.parse(arguments);

    // Process the parsed arguments.
    if (results.flag('help')) {
      printUsage(argParser);
      return;
    }
    if (results.flag('version')) {
      print('hottie version: $version');
      return;
    }

    final level = results.option('loggerLevel');
    if (level != null) {
      logger.level = Level.LEVELS.where((x) => x.name == level).firstOrNull;
    }

    if (results.flag('verbose')) {
      logger.level = Level.ALL;
    }

    final command = results.command;

    if (command != null) {
      switch (command.name) {
        case 'run':
          for (final file in command.rest) {
            if (!File(file).existsSync()) {
              logger.shout('$file does not exist');
              exit(-1);
            }
          }

          final frontend = HottieFrontendNew();
          await frontend.run(RelativePaths(command.rest.toSet()));
      }
    }
  } on FormatException catch (e) {
    // Print usage information if an invalid argument was provided.
    print(e.message);
    print('');
    printUsage(argParser);
  }
}
