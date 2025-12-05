import 'dart:io';

import 'package:ansicolor/ansicolor.dart';
import 'package:logging/logging.dart';

const hottieReloadSpell = '[HOTTIE:RELOAD]';
const hottieFromScriptEnvironmentKey = 'HOTTIE_FROM_SCRIPT';

final Logger logger = _Printer().create();

class _Printer {
  Logger create() {
    ansiColorDisabled = false;
    final logger = Logger.root;
    logger.onRecord.listen(_onData);
    return logger;
  }

  final _startTime = DateTime.now();
  final timePen = AnsiPen()..gray(level: 0.5);
  final messagePen = AnsiPen()..black();

  final Map<Level, String> levels = {
    Level.FINEST: 'F',
    Level.FINER: 'F',
    Level.FINE: 'F',
    Level.CONFIG: 'C',
    Level.INFO: 'ℹ️',
    Level.WARNING: '⚠️',
    Level.SEVERE: '‼️',
    Level.SHOUT: '🚨🚨🚨🚨',
    Level.OFF: '-',
  };

  void _onData(LogRecord record) {
    final time = record.time.difference(_startTime);
    final timeString = timePen(time);
    final level = levels[record.level];

    stdout.writeln('$level $timeString ${messagePen(record.message)}');
  }
}

extension FutureExtension<T> on Future<T> {
  void withLogging() {
    then((_) {}, onError: (Object e, StackTrace st) => logger.severe(e.toString(), e, st)).ignore();
  }
}

// class _SimplePrinter extends SimplePrinter {
//   final start = DateTime.now();

//   @override
//   List<String> log(LogEvent event) {
//     if (event.level == Level.error) {
//       return PrettyPrinter().log(event);
//     }

//     final color = AnsiColor.fg(AnsiColor.grey(0.5));
//     final output = super.log(event).first;
//     final t = event.time.difference(start);
//     final time = color(t.toString());

//     // final hh = t.hour.toString().padLeft(2, '0');
//     // final mm = t.minute.toString().padLeft(2, '0');
//     // final ss = t.second.toString().padLeft(2, '0');
//     // final sss = t.millisecond.toString().padLeft(3, '0');
//     // final time = color('$hh:$mm:$ss:$sss');

//     return ['$time $output'];
//   }
// }


  // void _onResults(List<TestGroupResults> value) {
  //   _previouslyFailed = value.where((x) => !x.isSuccess).map((x) => x.path).toSet();

  //   var passed = 0;
  //   var skipped = 0;

  //   for (final testFile in value) {
  //     passed += testFile.passed.length;
  //     skipped += testFile.skipped;
  //     for (final failedTest in testFile.failed) {
  //       for (final error in failedTest.errors) {
  //         final trace = Trace.from(error.stackTrace);
  //         var frame = trace.frames.where((x) => x.uri.toString().contains(testFile.path)).firstOrNull;

  //         frame ??= trace.frames.where((x) => !x.isCore).firstOrNull;

  //         frame ??= trace.frames.firstOrNull;

  //         logger.i('🔴 ${failedTest.name} in ${frame?.location}\n${error.error}');
  //       }
  //       return;
  //     }
  //   }

  //   final skippedString = skipped > 0 ? '($skipped skipped)' : '';
  //   logger.i('✅ $passed $skippedString');
  // }
  //
