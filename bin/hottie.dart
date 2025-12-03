#!/usr/bin/env dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hottie/src/utils/logger.dart';

const _filterOutput = false;

/// Watches Dart files and automatically triggers hot reload by sending 'r' to flutter run
Future<void> main() async {
  final process = await _startFlutter();
  _forwardOutput(process);
  exit(await process.exitCode);
}

Future<Process> _startFlutter() async {
  final program = Platform.environment['FLUTTER_PATH'] ?? 'flutter';

  final args = ['run', 'test/main_hottie.dart', '-d', 'flutter-tester', '--no-pub'];

  return Process.start(
    program,
    args,
    environment: {
      'HOTTIE_FROM_SCRIPT': '1',
    },
  );
}

void _forwardOutput(Process process) {
  process.stdout.transform(utf8.decoder).listen((line) {
    // Check if Flutter app is requesting a reload
    if (line.contains(hottieReloadSpell)) {
      process.stdin.write('r');
      return;
    }

    if (line.startsWith('[') || !_filterOutput) {
      stdout.write(line);
    }
  });
  process.stderr.listen(stderr.add);

  // Forward stdin in raw mode so single keypresses work
  stdin.echoMode = false;
  stdin.lineMode = false;
  stdin.listen(process.stdin.add);
}
