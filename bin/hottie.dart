#!/usr/bin/env dart

import 'dart:async';
import 'dart:io';

/// Watches Dart files and automatically triggers hot reload by sending 'r' to flutter run
Future<void> main() async {
  final process = await _startFlutter();
  _forwardOutput(process);
  _watchFiles(process);
  exit(await process.exitCode);
}

Future<Process> _startFlutter() async {
  Directory.current = '/Users/pawel.szot/Projekty/Experiments/hottie/example';
  return Process.start(
    '/Users/pawel.szot/fvm/versions/3.38.3/bin//flutter',
    ['run', 'test/main_hottie.dart', '-d', 'flutter-tester', '--no-pub'],
  );
}

void _forwardOutput(Process process) {
  process.stdout.listen(stdout.add);
  process.stderr.listen(stderr.add);
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
