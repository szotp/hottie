import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

import 'utils/logger.dart';

Future<VmService?> vmServiceConnect() async {
  final serviceInfo = await Service.getInfo();
  final serverUri = serviceInfo.serverUri;

  if (serverUri == null) {
    return null;
  }

  final wsUri = 'ws://${serverUri.authority}${serverUri.path}ws';

  return vmServiceConnectUri(wsUri);
}

typedef RelativePath = String;

extension type const Files(Set<String> uris) {
  factory Files.decode(String route) {
    final testPaths = (jsonDecode(route) as List).cast<RelativePath>().toSet();
    return Files(testPaths);
  }

  static const empty = Files({});

  String encode() => jsonEncode(uris.map((x) => x).toList());

  String describe() {
    if (uris.length > 3) {
      return '${uris.length} files';
    } else {
      return uris.join(', ');
    }
  }
}

class ScriptChangeChecker {
  ScriptChangeChecker(this._vm, this.isolateId);
  final String isolateId;
  final VmService _vm;

  /// script.relativePath -> script.id
  Map<RelativePath, String>? _previousState; // map from script uri to script hash

  Future<Files> checkLibraries() async {
    logger.fine('Check libraries at $isolateId');
    final sw = Stopwatch();
    sw.start();

    final previous = _previousState;
    final scripts = await _findTestScripts(isolateId);
    final currentState = <RelativePath, String>{};
    final changed = <String>{};

    for (final script in scripts) {
      final key = script.uri!;
      currentState[key] = script.id!;

      if (previous != null && previous[key] != script.id!) {
        changed.add(key);
      }
    }
    _previousState = currentState;
    return Files(changed.toSet());
  }

  Stream<Future<Files>> observe() async* {
    await checkLibraries();
    final vm = _vm;
    vm.streamListen(EventStreams.kIsolate).withLogging();
    yield* vm.onIsolateEvent.where((event) => event.kind == EventKind.kIsolateReload).map((event) => checkLibraries());
  }

  Future<List<ScriptRef>> _findTestScripts(String isolateId) async {
    final scripts = await _vm.getScripts(isolateId);
    return scripts.scripts!.where((x) => x.isTest).toList();
  }
}

extension on ScriptRef {
  /// Tests are not part of any package, so their uri always starts with `file:///`
  bool get isTest {
    return uri!.startsWith('file:///') && uri!.endsWith('_test.dart');
  }
}
