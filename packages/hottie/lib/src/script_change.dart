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

extension type Files(Set<Uri> uris) {
  factory Files.decode(String route) {
    final testPaths = (jsonDecode(route) as List).cast<RelativePath>().map(Uri.parse).toSet();
    return Files(testPaths);
  }

  static final empty = Files(const {});

  String encode() => jsonEncode(uris.map((x) => x.toString()).toList());

  String describe() {
    if (uris.length > 3) {
      return '${uris.length} files';
    } else {
      return uris.join(', ');
    }
  }
}

class ScriptChangeChecker {
  ScriptChangeChecker(this._vm) {
    // first check to determine a baseline
    _load().withLogging();
  }
  final VmService _vm;

  Future<void> _load() async {
    final info = await _vm.getVM();
    final isolateId = info.isolates!.first.id!;
    checkLibraries(isolateId).withLogging();
  }

  /// script.relativePath -> script.id
  Map<RelativePath, String>? _previousState; // map from script uri to script hash

  Future<Files> checkLibraries(String isolateId) async {
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
    return Files(changed.map(Uri.parse).toSet());
  }

  Stream<Files> observe() async* {
    final vm = _vm;
    vm.streamListen('Isolate').withLogging();
    yield* vm.onIsolateEvent.where((event) => event.kind == 'IsolateReload').asyncMap((event) => checkLibraries(event.isolate!.id!));
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
