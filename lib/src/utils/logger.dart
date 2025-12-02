void logger(Object message) {
  final d = DateTime.now();
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  final ss = d.second.toString().padLeft(2, '0');
  final mse = d.millisecond.toString().padLeft(3, '0');

  final string = '$hh:$mm:$ss:$mse';

  print('[$string] $message'); // ignore: avoid_print hottie does not work in release mode anyway
}

extension FutureExtension<T> on Future<T> {
  void ignoreWithLogging() {
    then((_) {}, onError: logger).ignore();
  }
}
