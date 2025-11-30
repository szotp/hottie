import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class SpawnHostApi {
  void spawn(String entryPoint, List<String> args);
  void close();
}

/// `dart run pigeon --input pigeons.dart `
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/model.g.dart',
    dartOptions: DartOptions(),
    swiftOut: 'ios/Classes/Messages.g.swift',
    dartPackageName: 'hottie',
  ),
)
class TestResult {
  late final String name;
  late final List<TestResultError> errors;
}

class TestResultError {
  late final String message;
}

class TestGroupResults extends FromIsolate {
  late final int skipped;
  late final List<TestResult> failed;
  late final List<TestResult> passed;
}

enum TestStatus {
  starting,
  waiting,
  running,
  finished;
}

class TestStatusFromIsolate extends FromIsolate {
  late final TestStatus status;
}

sealed class FromIsolate {}
