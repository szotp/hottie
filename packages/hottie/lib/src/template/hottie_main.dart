// You can edit this file to apply filters, etc.

import '../../hottie_insider.dart';
import 'hottie_tests.g.dart';

Future<void> main() => hottie(onHotReload, TestFileId.values);

/// Decides which tests to run
void onHotReload(HottieContext context, RunTestsRequest request) {
  if (context.isInitialRun) {
    request.tests.addAll(TestFileId.values);
  } else {
    request.tests.addAll(context.changedTests);
  }
}
