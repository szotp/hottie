import 'dart:async';
import 'dart:io';

import 'package:stack_trace/stack_trace.dart';

const ansiReplaceLine = '\r\x1b[K';
const progressPlaceholder = '{PROGRESS}';
const isHottieWatch = bool.fromEnvironment('HOTTIE_WATCH');

final printer = ConsoleOutput();
final Logger logger = printer;

abstract class Logger {
  void log(LogLevel level, Object message, [StackTrace? stackTrace]);

  void fine(Object message) => log(LogLevel.verbose, message);
  void info(Object message) => log(LogLevel.info, message);
  void warning(Object message) => log(LogLevel.warning, message);
  void severe(Object message, StackTrace stackTrace) => log(LogLevel.error, message, stackTrace);
}

class LogLevel {
  const LogLevel(this.prefix, this.importance);

  final String prefix;
  final int importance;

  static const verbose = LogLevel('F ', 0);
  static const info = LogLevel('ℹ️ ', 1);
  static const warning = LogLevel('⚠️ ', 2);
  static const error = LogLevel('‼️ ', 3);
  static const tragedy = LogLevel('🚨', 4);

  String format(String message) => message;
}

class ConsoleOutput extends Logger {
  ConsoleOutput() {
    if (isHottieWatch) {
      appendLocation = false;
    }
  }
  int minimumImportance = 1;
  bool appendLocation = true;

  static const _padding = '                 ';

  String _timePen(String input) => input;
  String _locationPen(String location) => location;

  @override
  void log(LogLevel level, Object message, [StackTrace? stackTrace]) {
    if (level.importance < minimumImportance) {
      return;
    }

    final timestamp = DateTime.now();
    final hh = timestamp.hour.toString().padLeft(2, '0');
    final mm = timestamp.minute.toString().padLeft(2, '0');
    final ss = timestamp.second.toString().padLeft(2, '0');
    final sss = timestamp.millisecond.toString().padLeft(3, '0');
    final timeString = _timePen('$hh:$mm:$ss:$sss');

    final lines = message.toString().split('\n');
    lines[0] = '$timeString ${level.prefix} ${level.format(lines.first)}';

    if (appendLocation) {
      final trace = Trace.from(stackTrace ?? StackTrace.current);
      final location = trace.frames.where((x) => !x.location.contains('logger.dart') && !x.location.contains('matcher')).firstOrNull?.location;
      lines[0] = '${lines[0]} ${_locationPen('at $location ')}';
    }

    for (var i = 1; i < lines.length; i++) {
      lines[i] = '$_padding ${level.format(lines[i])}';
    }

    write(lines);
  }

  void writeln(String line) {
    write([line]);
  }

  final updatingLinesPossible = true;

  void updateLine(String line) {
    if (updatingLinesPossible) {
      stdout.writeln('$progressPlaceholder$line');
    } else {
      stdout.writeln(line);
    }
  }

  void write(List<String> lines) {
    if (_progress != null && updatingLinesPossible) {
      stdout.writeln(progressPlaceholder);
    }
    lines.forEach(stdout.writeln);
  }

  StdoutProgress? _progress;
  StdoutProgress start(String label) {
    _progress?.finish('Interrupted');
    _progress = StdoutProgress(label, () {
      _progress = null;
    });
    return _progress!;
  }
}

extension FutureExtension<T> on Future<T> {
  void withLogging() {
    then((_) {}, onError: logger.severe).ignore();
  }
}

class StdoutProgress {
  StdoutProgress(this._label, this.onFinished) {
    stdout.write('$_label... (0.0s)');
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      assert(_timer != null, '');
      emit();
    });
  }
  final void Function() onFinished;
  final _watch = Stopwatch()..start();
  Timer? _timer;
  String _label;

  void emit() {
    final elapsed = (_watch.elapsed.inMilliseconds / 1000).toStringAsFixed(1);
    printer.updateLine('$_label... (${elapsed}s)');
  }

  void finish(String? finalInfo) {
    emit();
    _timer?.cancel();
    _timer = null;

    if (finalInfo != null) {
      stdout.writeln('\n$finalInfo');
    } else {
      stdout.writeln(_label);
    }

    onFinished();
  }

  void update(String newLabel) {
    _label = newLabel;
    emit();
  }
}
