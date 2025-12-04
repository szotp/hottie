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
    if (event.level == Level.error) {
      return PrettyPrinter().log(event);
    }

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
