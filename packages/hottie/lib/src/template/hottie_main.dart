// You can edit this file to apply filters, etc.

import '../../hottie_insider.dart';
import 'hottie_tests.g.dart';

/// Observe hot reload events to spawn test cycles.
Future<void> main() => hottie(filesForTesting);

Iterable<TestId> filesForTesting(IsolateArguments arguments) {
  return TestId.values.where(arguments.changedTests.contains);
}
