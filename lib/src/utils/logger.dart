import 'dart:io';

import 'package:stack_trace/stack_trace.dart';

const hottieReloadSpell = '[HOTTIE:RELOAD]';
const hottieFromScriptEnvironmentKey = 'HOTTIE_FROM_SCRIPT';

const logger = Logger();

extension FutureExtension<T> on Future<T> {
  void withLogging() {
    then((_) {}, onError: logger.error).ignore();
  }
}

class Logger {
  const Logger();
  void info(Object message) {
    stdout.writeln(message.toString());
  }

  void error(Object error, StackTrace stackTrace) {
    info(error.toString());
    info(Trace.from(stackTrace).terse.toString());
  }

  void requestReload(String changedFile) {
    info('$hottieReloadSpell because of $changedFile');
  }
}
