import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class IsolateStarted {
  void initialize(int rawHandle);
}

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

class TestGroupResults {
  late final int skipped;
  late final List<TestResult> failed;
  late final List<TestResult> passed;
}

sealed class IsolateMessage {}

final class RunTestsIsolateMessage extends IsolateMessage {
  late final int rawHandle;
}

class SetCurrentDirectoryIsolateMessage extends IsolateMessage {
  late final String root;
}
