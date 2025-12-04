import 'dart:developer';

void hottie(Map<String, void Function()> tests) {
  registerExtension('ext.hottie.test', (_, args) async {
    for (final test in tests.values) {
      test();
    }

    return ServiceExtensionResponse.result('{}');
  });
}
