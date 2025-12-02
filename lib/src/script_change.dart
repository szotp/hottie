import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:isolate' as iso;

import 'package:hottie/src/utils/logger.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

Future<VmService> _vmServiceConnect() async {
  final serviceInfo = await Service.getInfo();
  final serverUri = serviceInfo.serverUri!;
  final wsUri = 'ws://${serverUri.authority}${serverUri.path}ws';

  return vmServiceConnectUri(wsUri);
}

typedef RelativePath = String;

extension type RelativePaths(Set<RelativePath> paths) {
  factory RelativePaths.decode(String route) {
    final testPaths = (jsonDecode(route) as List).cast<RelativePath>().toSet();
    return RelativePaths(testPaths);
  }

  String encode() => jsonEncode(paths.toList());
}

class ScriptChangeChecker {
  ScriptChangeChecker() {
    _vm.then((value) {
      _disposable = value;
    }).ignoreWithLogging();

    // first check to determine a baseline
    checkLibraries().ignoreWithLogging();
  }

  final String _isolateId = Service.getIsolateId(iso.Isolate.current)!;

  /// script.relativePath -> script.id
  Map<RelativePath, String>? _previousState; // map from script uri to script hash

  final Future<VmService> _vm = _vmServiceConnect();
  VmService? _disposable;

  Future<RelativePaths> checkLibraries() async {
    final sw = Stopwatch();
    sw.start();

    final previous = _previousState;
    final scripts = await _findTestScripts();
    final currentState = <RelativePath, String>{};
    final changed = <String>{};

    for (final script in scripts) {
      final key = script.relativePath;
      currentState[key] = script.id!;

      if (previous != null && previous[key] != script.id!) {
        changed.add(key);
      }
    }
    _previousState = currentState;
    return RelativePaths(changed);
  }

  void dispose() => _disposable?.dispose();

  Stream<RelativePaths> observe() async* {
    final vm = await _vm;
    vm.streamListen('Isolate').ignoreWithLogging();
    yield* vm.onIsolateEvent.where((event) => event.kind == 'IsolateReload').asyncMap((_) => checkLibraries());
  }

  Future<List<ScriptRef>> _findTestScripts() async {
    final scripts = await (await _vm).getScripts(_isolateId);
    return scripts.scripts!.where((x) => x.isTest).toList();
  }

  Future<bool> performHotReload() async {
    final result = await (await _vm).reloadSources(_isolateId, force: true);
    if (result.success != true) {
      logger('Hot reload failed: ${result.json}');
    }
    return result.success ?? false;
  }
}

extension on ScriptRef {
  /// Tests are not part of any package, so their uri always starts with `file:///`
  bool get isTest {
    return uri!.startsWith('file:///') && uri!.endsWith('_test.dart');
  }

  RelativePath get relativePath {
    final uri = Uri.parse(this.uri!);
    final segments = uri.pathSegments;
    final index = segments.indexOf('test');
    return segments.sublist(index + 1).join('/');
  }
}
