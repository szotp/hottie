import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

String _pathJoin(String a, String b) {
  return '$a${Platform.pathSeparator}$b';
}

Uri findAssetsFolderPath() {
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

/// Setup mocking of platform assets if `UNIT_TEST_ASSETS` is defined.
void mockFlutterAssets() {
  const appName = 'fuck';
  final assetFolderPath = findAssetsFolderPath().toFilePath();

  const prefix = 'packages/$appName}/';

  /// Navigation related actions (pop, push, replace) broadcasts these actions via
  /// platform messages.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.navigation,
    (MethodCall methodCall) async {
      return null;
    },
  );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
    'flutter/assets',
    (ByteData? message) {
      assert(message != null, '');
      var key = utf8.decode(message!.buffer.asUint8List());
      var asset = File(_pathJoin(assetFolderPath, key));

      if (!asset.existsSync()) {
        // For tests in package, it will load assets with its own package prefix.
        // In this case, we do a best-effort look up.
        if (!key.startsWith(prefix)) {
          return null;
        }

        key = key.replaceFirst(prefix, '');
        asset = File(_pathJoin(assetFolderPath, key));
        if (!asset.existsSync()) {
          return null;
        }
      }

      final encoded = Uint8List.fromList(asset.readAsBytesSync());
      return SynchronousFuture<ByteData>(encoded.buffer.asByteData());
    },
  );
}
