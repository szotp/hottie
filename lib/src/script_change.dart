import 'dart:async';
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
  Map<RelativePath, String>?
      _previousState; // map from script uri to script hash

  final Future<VmService> _vm = _vmServiceConnect();
  VmService? _disposable;

  Future<List<RelativePath>> checkLibraries() async {
    final sw = Stopwatch();
    sw.start();

    final previous = _previousState;
    final scripts = await _findTestScripts();
    final currentState = <RelativePath, String>{};
    final changed = <String>[];

    for (final script in scripts) {
      final key = script.relativePath;
      currentState[key] = script.id!;

      if (previous != null && previous[key] != script.id!) {
        changed.add(key);
      }
    }
    _previousState = currentState;
    return changed;
  }

  void dispose() => _disposable?.dispose();

  Stream<List<RelativePath>> observe() async* {
    final vm = await _vm;
    vm.streamListen('Isolate').ignoreWithLogging();
    yield* vm.onIsolateEvent
        .where((event) => event.kind == 'IsolateReload')
        .asyncMap((_) => checkLibraries());
  }

  Future<List<ScriptRef>> _findTestScripts() async {
    final scripts = await (await _vm).getScripts(_isolateId);
    return scripts.scripts!.where((x) => x.isTest).toList();
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
