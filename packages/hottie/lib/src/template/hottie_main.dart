// You can edit this file to apply filters, etc.

import '../../hottie_insider.dart';
import 'hottie_tests.g.dart';

/// Observe hot reload events to spawn test cycles.
Future<void> main() => mainWatch();

/// Entry point for isolate spawned for every test cycle. Name `hottieIsolated` must not change.
@pragma('vm:entry-point')
Future<void> hottieIsolated() {
  final configuration = RunTestsConfiguration.from(TestId.values);
  configuration.onlyChangedTests();
  // here you can customize which tests to run
  return mainRunTests(configuration);
}
