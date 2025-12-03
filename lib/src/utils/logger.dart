import 'dart:io';

import 'package:stack_trace/stack_trace.dart';

const hottieReloadSpell = '[HOTTIE:RELOAD]';

void logger(Object message) {
  final d = DateTime.now();
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  final ss = d.second.toString().padLeft(2, '0');
  final mse = d.millisecond.toString().padLeft(3, '0');

  final string = '$hh:$mm:$ss:$mse';

  stdout.writeln('[$string] $message');
}

void loggerError(Object error, StackTrace trace) {
  logger(error);
  logger(Trace.from(trace).terse);
}

void requestReload(String changedFile) {
  logger('$hottieReloadSpell because of $changedFile');
}

extension FutureExtension<T> on Future<T> {
  void withLogging() {
    then((_) {}, onError: logger).ignore();
  }
}
