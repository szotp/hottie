import 'dart:io';

import 'package:ansicolor/ansicolor.dart';
import 'package:logging/logging.dart';
import 'package:stack_trace/stack_trace.dart';

const hottieReloadSpell = '[HOTTIE:RELOAD]';
const hottieFromScriptEnvironmentKey = 'HOTTIE_FROM_SCRIPT';

final Logger logger = _Printer().create();

class _Style extends AnsiPen {
  _Style(this.prefix);

  final String prefix;
}

class _Printer {
  Logger create() {
    recordStackTraceAtLevel = Level.INFO;
    ansiColorDisabled = false;
    final logger = Logger.root;
    //logger.level = Level.ALL;
    logger.onRecord.listen(_onData);
    return logger;
  }

  final _startTime = DateTime.now();
  final timePen = AnsiPen()..gray(level: 0.5);

  final locationPen = AnsiPen()..gray(level: 0.95);
  final Map<Level, _Style> levels = {
    Level.FINEST: _Style('F'),
    Level.FINER: _Style('F'),
    Level.FINE: _Style('F'),
    Level.CONFIG: _Style('C'),
    Level.INFO: _Style('ℹ️'),
    Level.WARNING: _Style('⚠️')..red(bold: true),
    Level.SEVERE: _Style('‼️'),
    Level.SHOUT: _Style('🚨🚨🚨🚨'),
    Level.OFF: _Style('-'),
  };

  static const _padding = '                 ';

  void _onData(LogRecord record) {
    final time = record.time.difference(_startTime);
    final timeString = timePen(time);
    final level = levels[record.level]!;

    final trace = Trace.from(record.stackTrace ?? StackTrace.current);
    final location = trace.frames.firstWhere((x) => !x.location.contains('logger.dart') && !x.location.contains('matcher')).location;

    final lines = record.message.split('\n');
    stdout.writeln('$timeString ${level.prefix} ${level(lines.first)} ${locationPen('at $location ')}');

    for (final line in lines.skip(1)) {
      stdout.writeln('$_padding ${level(line)}');
    }
  }
}

extension FutureExtension<T> on Future<T> {
  void withLogging() {
    then((_) {}, onError: (Object e, StackTrace st) => logger.severe(e.toString(), e, st)).ignore();
  }
}
