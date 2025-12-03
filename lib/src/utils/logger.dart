import 'dart:developer';
import 'dart:io';

import 'package:stack_trace/stack_trace.dart';

const hottieReloadSpell = '[HOTTIE:RELOAD]';
const hottieFromScriptEnvironmentKey = 'HOTTIE_FROM_SCRIPT';
final isRunningInTerminal = Platform.environment[hottieFromScriptEnvironmentKey] == '1';

void logger(Object message) {
  final d = DateTime.now();
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  final ss = d.second.toString().padLeft(2, '0');
  final mse = d.millisecond.toString().padLeft(3, '0');

  final string = '$hh:$mm:$ss:$mse';
  if (!isRunningInTerminal) {
    log(message.toString(), name: string);
  } else {
    stdout.writeln('[$string] $message');
  }
}

void loggerError(Object error, StackTrace trace) {
  logger('${Trace.from(trace).terse}\n$error');
}

void requestReload(String changedFile) {
  logger('$hottieReloadSpell because of $changedFile');
}

extension FutureExtension<T> on Future<T> {
  void withLogging() {
    then((_) {}, onError: logger).ignore();
  }
}
