import 'package:logger/logger.dart';

const hottieReloadSpell = '[HOTTIE:RELOAD]';
const hottieFromScriptEnvironmentKey = 'HOTTIE_FROM_SCRIPT';

final logger = Logger(printer: _SimplePrinter());

extension FutureExtension<T> on Future<T> {
  void withLogging() {
    then((_) {}, onError: (Object e, StackTrace st) => logger.e(e, stackTrace: st)).ignore();
  }
}

class _SimplePrinter extends SimplePrinter {
  @override
  List<String> log(LogEvent event) {
    final color = AnsiColor.fg(AnsiColor.grey(0.5));
    final output = super.log(event).first;
    final t = event.time;
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final ss = t.second.toString().padLeft(2, '0');
    final sss = t.millisecond.toString().padLeft(3, '0');
    final time = color('$hh:$mm:$ss:$sss');
    return ['$time $output'];
  }
}
