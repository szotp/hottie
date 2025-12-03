#!/usr/bin/env dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _filterOutput = false;

/// Watches Dart files and automatically triggers hot reload by sending 'r' to flutter run
Future<void> main() async {
  final process = await _startFlutter();
  _forwardOutput(process);
  _watchFiles(process);
  exit(await process.exitCode);
}

Future<Process> _startFlutter() async {
  final program = Platform.environment['FLUTTER_PATH'] ?? 'flutter';

  final args = ['run', 'test/main_hottie.dart', '-d', 'flutter-tester', '--no-pub'];

  return Process.start(
    program,
    args,
  );
}

void _forwardOutput(Process process) {
  process.stdout.transform(utf8.decoder).listen((line) {
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

void _watchFiles(Process process) {
  Timer? debounceTimer;

  void onFileChange(FileSystemEvent event) {
    if (event.type != FileSystemEvent.modify || !event.path.endsWith('.dart')) {
      return;
    }

    debounceTimer?.cancel();
    debounceTimer = Timer(const Duration(milliseconds: 500), () {
      process.stdin.write('r');
    });
  }

  for (final dir in [Directory('lib'), Directory('test')]) {
    if (dir.existsSync()) {
      dir.watch(recursive: true).listen(onFileChange);
    }
  }
}
