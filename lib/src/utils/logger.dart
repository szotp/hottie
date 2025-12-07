import 'dart:async';
import 'dart:io';

import 'package:ansicolor/ansicolor.dart';
import 'package:logging/logging.dart';
import 'package:stack_trace/stack_trace.dart';

const hottieReloadSpell = '[HOTTIE:RELOAD]';
const hottieFromScriptEnvironmentKey = 'HOTTIE_FROM_SCRIPT';

const _ansiReplaceLine = '\r\x1b[K';

final printer = ConsoleOutput();
final Logger logger = printer.create();

class _Style extends AnsiPen {
  _Style(this.prefix);

  final String prefix;
}

class ConsoleOutput {
  Logger create() {
    recordStackTraceAtLevel = Level.INFO;
    ansiColorDisabled = false;
    final logger = Logger.root;
    //logger.level = Level.ALL;
    logger.onRecord.listen(_onData);
    return logger;
  }

  final _startTime = DateTime.now();
  final _timePen = AnsiPen()..gray(level: 0.5);
  final _locationPen = AnsiPen()..gray(level: 0.95);

  final Map<Level, _Style> _levels = {
    Level.FINEST: _Style('F '),
    Level.FINER: _Style('F '),
    Level.FINE: _Style('F '),
    Level.CONFIG: _Style('C '),
    Level.INFO: _Style('ℹ️ '),
    Level.WARNING: _Style('⚠️ ')..red(bold: true),
    Level.SEVERE: _Style('‼️ '),
    Level.SHOUT: _Style('🚨')..red(bg: true),
    Level.OFF: _Style('-'),
  };

  static const _padding = '                 ';

  void _onData(LogRecord record) {
    final time = record.time.difference(_startTime);
    final timeString = _timePen(time);
    final level = _levels[record.level]!;

    final trace = Trace.from(record.stackTrace ?? StackTrace.current);
    final location = trace.frames.where((x) => !x.location.contains('logger.dart') && !x.location.contains('matcher')).firstOrNull?.location;

    final lines = record.message.split('\n');

    lines[0] = '$timeString ${level.prefix} ${level(lines.first)} ${_locationPen('at $location ')}';

    for (var i = 1; i < lines.length; i++) {
      lines[i] = '$_padding ${level(lines[i])}';
    }

    write(lines);
  }

  void writeln(String line) {
    write([line]);
  }

  final updatingLinesPossible = true;

  void updateLine(String line) {
    if (updatingLinesPossible) {
      stdout.write('$_ansiReplaceLine$line');
    } else {
      stdout.writeln(line);
    }
  }

  void write(List<String> lines) {
    if (_progress != null && updatingLinesPossible) {
      stdout.write(_ansiReplaceLine);
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
    then((_) {}, onError: (Object e, StackTrace st) => logger.severe(e.toString(), e, st)).ignore();
  }
}

class StdoutProgress {
  StdoutProgress(this._label, this.onFinished) {
    stdout.write('$_label... (0.0s)');
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      assert(_timer != null, '');
      print();
    });
  }
  final void Function() onFinished;
  final _watch = Stopwatch()..start();
  Timer? _timer;
  String _label;

  void print() {
    final elapsed = (_watch.elapsed.inMilliseconds / 1000).toStringAsFixed(1);
    printer.updateLine('$_label... (${elapsed}s)');
  }

  void finish(String finalInfo) {
    print();
    _timer?.cancel();
    _timer = null;

    stdout.writeln('\n$finalInfo.');
    onFinished();
  }

  void update(String newLabel) {
    _label = newLabel;
    print();
  }
}
