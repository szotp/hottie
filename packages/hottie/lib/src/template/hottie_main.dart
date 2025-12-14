// You can edit this file to apply filters, etc.

import '../../hottie_insider.dart';
import 'hottie_tests.g.dart' as t;

/// Observe hot reload events to spawn test cycles.
Future<void> main() => mainWatch();

/// Entry point for isolate spawned for every test cycle. Name `hottieIsolated` must not change.
@pragma('vm:entry-point')
Future<void> hottieIsolated() {
  // here you can customize which tests to run
  return mainRunTests(t.allTests);
}
