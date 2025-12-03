import 'dart:io';

void logger(Object message) {
  final d = DateTime.now();
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  final ss = d.second.toString().padLeft(2, '0');
  final mse = d.millisecond.toString().padLeft(3, '0');

  final string = '$hh:$mm:$ss:$mse';

  stdout.writeln('[$string] $message');
}

extension FutureExtension<T> on Future<T> {
  void ignoreWithLogging() {
    then((_) {}, onError: logger).ignore();
  }
}
