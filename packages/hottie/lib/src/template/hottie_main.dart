// You can edit this file to apply filters, etc.

import '../../hottie_insider.dart';
import 'hottie_tests.g.dart';

Future<void> main() => hottie(onHotReload);

/// Returns files that should be tested
TestFiles onHotReload(IsolateArguments arguments) {
  return TestFileId.values.where(arguments.changedTests.contains);
}
