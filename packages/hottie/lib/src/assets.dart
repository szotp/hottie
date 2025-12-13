import 'dart:io';

Uri findAssetsFolder() {
  // find .dart-tool/flutter_build/<latest>/flutter_assets.d
  final dartToolDir = Directory('.dart_tool/flutter_build');
  if (!dartToolDir.existsSync()) {
    throw Exception('Could not find .dart_tool/flutter_build directory');
  }

  // Get the latest build directory (sorted by modification time)
  final buildDirs = dartToolDir.listSync().whereType<Directory>().where((dir) => !dir.path.endsWith('.')).toList()
    ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

  if (buildDirs.isEmpty) {
    throw Exception('No build directories found in .dart_tool/flutter_build');
  }

  final latestBuildDir = buildDirs.first;
  final assetsFile = File('${latestBuildDir.path}/flutter_assets.d');

  if (!assetsFile.existsSync()) {
    throw Exception('flutter_assets.d not found in ${latestBuildDir.path}');
  }

  // get path for AssetManifest.json
  final content = assetsFile.readAsStringSync();
  final assetManifestMatch = RegExp(r'(\S+/AssetManifest\.json)').firstMatch(content);

  if (assetManifestMatch == null) {
    throw Exception('AssetManifest.json path not found in flutter_assets.d');
  }

  final assetManifestPath = assetManifestMatch.group(1)!;

  // return its parent directory
  return Uri.file(File(assetManifestPath).parent.path);
}
