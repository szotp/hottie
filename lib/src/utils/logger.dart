import 'package:mason_logger/mason_logger.dart';
import 'package:stack_trace/stack_trace.dart';

const hottieReloadSpell = '[HOTTIE:RELOAD]';
const hottieFromScriptEnvironmentKey = 'HOTTIE_FROM_SCRIPT';

final Logger logger = Logger();

void loggerError(Object error, StackTrace trace) {
  logger.err('${Trace.from(trace).terse}\n$error');
}

void requestReload(String changedFile) {
  logger.info('$hottieReloadSpell because of $changedFile');
}

extension FutureExtension<T> on Future<T> {
  void withLogging() {
    then((_) {}, onError: loggerError).ignore();
  }
}
