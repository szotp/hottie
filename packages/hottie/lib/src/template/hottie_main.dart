// You can edit this file to apply filters, etc.

import '../../hottie_insider.dart';
import 'hottie_tests.g.dart';

Future<void> main() => hottie(onHotReload);

/// Returns files that should be tested
RunTestsRequest onHotReload(IsolateArguments arguments) {
  if (arguments.isInitialRun) {
    return RunTestsRequest(TestFileId.values);
  }

  return RunTestsRequest.changed(TestFileId.values, arguments);
}
