import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:hottie/src/utils/logger.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

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

extension type RelativePaths(Set<RelativePath> paths) {
  factory RelativePaths.decode(String route) {
    final testPaths = (jsonDecode(route) as List).cast<RelativePath>().toSet();
    return RelativePaths(testPaths);
  }

  static final empty = RelativePaths(const {});

  List<Uri> get uris => paths.map((x) => Uri.file(File(x).absolute.path)).toList();

  String encode() => jsonEncode(paths.toList());

  String describe() {
    if (paths.length > 3) {
      return '${paths.length} files';
    } else {
      return paths.join(', ');
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

  Future<RelativePaths> checkLibraries(String isolateId) async {
    logger.fine('Check libraries at $isolateId');
    final sw = Stopwatch();
    sw.start();

    final previous = _previousState;
    final scripts = await _findTestScripts(isolateId);
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

  Stream<RelativePaths> observe() async* {
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

  RelativePath get relativePath {
    final uri = Uri.parse(this.uri!);
    final segments = uri.pathSegments;
    final index = segments.indexOf('test');
    return segments.sublist(index).join('/');
  }
}
