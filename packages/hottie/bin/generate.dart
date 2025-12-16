import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:args/command_runner.dart';
import 'package:hottie/src/utils/logger.dart';

const _mainPath = 'build/hottie_main.dart';
const _testsPath = 'build/hottie_tests.g.dart';

class TestFileHandle {
  TestFileHandle(this.packageName, this.uniqueId, this.uri);

  final String packageName;
  final String uniqueId;
  final Uri uri;

  static TestFileHandle? parse(FileSystemEntity file, Set<String> usedIds) {
    if (!file.path.endsWith('_test.dart') || file.path.contains('/.')) {
      return null;
    }

    final segments = file.uri.pathSegments;
    final testIndex = segments.indexOf('test');

    if (testIndex < 0) {
      return null;
    }

    final packageName = segments[testIndex - 1];
    final proposedId = segments.last.replaceAll('.dart', '');
    var uniqueId = proposedId;

    for (var i = 2; i < 100; i++) {
      if (usedIds.add(uniqueId)) {
        break;
      }
      uniqueId = '${proposedId}_$i';
    }

    return TestFileHandle(packageName, uniqueId, file.uri);
  }
}

class TestFileHandles {
  TestFileHandles(this.all);

  final List<TestFileHandle> all;

  late final List<String> packages = all.map((x) => x.packageName).toSet().toList()..sort();
}

TestFileHandles findTestsInCurrentDirectory() {
  final usedIds = <String>{};
  final files = Directory.current.listSync(recursive: true).map((file) => TestFileHandle.parse(file, usedIds)).nonNulls.toList();

  if (files.isEmpty) {
    logger.warning('No test files found in ${Directory.current}');
  }
  return TestFileHandles(files);
}

Future<String> determinHottieInsiderImport() async {
  // parse package config and check if hottie is available. if yes, return normal import
  final packageConfigFile = File('.dart_tool/package_config.json');

  if (!packageConfigFile.existsSync()) {
    throw Exception('.dart_tool/package_config.json not found. Run flutter pub get first.');
  }

  final packageConfigJson = jsonDecode(await packageConfigFile.readAsString()) as Map<String, dynamic>;
  final packages = packageConfigJson['packages'] as List<dynamic>;

  final hottiePackage = packages.firstWhere(
    (pkg) => (pkg as Map)['name'] == 'hottie',
    orElse: () => null,
  );

  if (hottiePackage != null) {
    // hottie package is available, use normal package import
    return "import 'package:hottie/hottie_insider.dart';";
  } else {
    // hottie not available as package, fall back to resolved path
    final resolved = await Isolate.resolvePackageUri(Uri.parse('package:hottie/hottie_insider.dart'));
    return "import '$resolved';";
  }
}

Future<Uri> generateMain(TestFileHandles testPaths, {bool overrideMain = false}) async {
  final hottieImport = await determinHottieInsiderImport();

  final imports = StringBuffer();
  final packages = StringBuffer();
  final tests = StringBuffer();

  for (final handle in testPaths.all) {
    imports.writeln("import '${handle.uri}' as import_${handle.uniqueId};");
    tests.writeln("${handle.uniqueId}('${handle.uri}', import_${handle.uniqueId}.main),");
  }

  for (final package in testPaths.packages) {
    packages.writeln('  $package,');
  }

  if (!Directory('build').existsSync()) {
    Directory('build').createSync();
  }
  await useTemplate('package:hottie/src/template/hottie_tests.g.dart', _testsPath, {
    'hottie_insider': hottieImport,
    '{imports}': imports.toString(),
    '{packages}': packages.toString(),
    '{tests}': tests.toString(),
  });

  if (!File(_mainPath).existsSync() || overrideMain) {
    await useTemplate('package:hottie/src/template/hottie_main.dart', _mainPath, {'hottie_insider': hottieImport});
  }

  return Uri.file(_mainPath);
}

Future<void> useTemplate(String packageUri, String destinationPath, Map<String, String> replacements) async {
  final hottieMain = await Isolate.resolvePackageUri(Uri.parse(packageUri));
  final contents = File.fromUri(hottieMain!).readAsLinesSync();

  for (final entry in replacements.entries) {
    final index = contents.indexWhere((x) => x.contains(entry.key));
    assert(index >= 0, '${entry.key} not found in template');
    contents[index] = entry.value;
  }

  File(destinationPath).writeAsStringSync(contents.join('\n'));
}

class GenerateCommand extends Command<void> {
  GenerateCommand() {
    argParser.addFlag('overrideMain');
  }
  @override
  String get description => 'generate hottie tests file';
  @override
  String get name => 'generate';

  @override
  Future<void>? run() async {
    final testPaths = findTestsInCurrentDirectory();
    final hottieUri = await generateMain(testPaths, overrideMain: argResults!.flag('overrideMain'));
    logger.info('Generated $hottieUri');
  }
}
