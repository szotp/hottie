// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:isolate' as iso;

import 'package:hottie/src/logger.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

class ScriptChangeObserver {
  final DependencyFinder _finder;

  Map<String, String>? _previousState; // map from script uri to script hash

  ScriptChangeObserver(this._finder);

  static Future<ScriptChangeObserver> connect() async {
    final finder = await DependencyFinder.connect();
    final observer = ScriptChangeObserver(finder);
    await observer.checkLibraries();
    return observer;
  }

  Future<List<Uri>> checkLibraries() async {
    final sw = Stopwatch();
    sw.start();
    final previous = _previousState;
    final scripts = await _finder.findCurrentPackageScripts(onlyTests: true);
    final currentState = <String, String>{};
    final changed = <Uri>[];

    for (final script in scripts) {
      final key = script.uri!;
      currentState[key] = script.id!;

      if (previous != null && previous[key] != script.id!) {
        changed.add(Uri.parse(script.uri!));
      }
    }
    _previousState = currentState;
    logHottie('checkLibraries took ${sw.elapsedMilliseconds}ms');
    return changed;
  }

  Future<void> runChangedTests() async {
    logHottie('runChangedTests 2');
  }
}

class DependencyFinder {
  static Future<DependencyFinder> connect() async {
    final serviceInfo = await Service.getInfo();
    final serverUri = serviceInfo.serverUri!;
    final wsUri = 'ws://${serverUri.authority}${serverUri.path}ws';

    final vm = await vmServiceConnectUri(wsUri);
    return DependencyFinder(vm);
  }

  final VmService _vm;
  DependencyFinder(this._vm);
  Future<void> dispose() => _vm.dispose();

  final _isolateId = Service.getIsolateId(iso.Isolate.current)!;

  Future<List<ScriptRef>> findCurrentPackageScripts({bool onlyTests = false}) async {
    final scripts = await _vm.getScripts(_isolateId);
    final tests = scripts.scripts!.where((x) => x.isTest).toList();

    if (onlyTests) {
      return tests;
    }

    final isCurrentPackage = IsCurrentPackage.fromScriptRefs(tests);
    return scripts.scripts!.where(isCurrentPackage.checkScriptRef).toList();
  }

  Future<List<LibraryNode>> findCurrentPackageLibraries() async {
    final refs = await findCurrentPackageScripts();
    final isCurrentPackage = IsCurrentPackage.fromScriptRefs(refs);

    final futures = refs.map((e) => _vm.getObject(_isolateId, e.libraryId));
    final urisFuture = _vm.lookupResolvedPackageUris(_isolateId, refs.map((e) => e.uri!).toList());

    final results = await Future.wait(futures);
    final uris = await urisFuture;

    final mapped = results.cast<Library>().indexed.map((x) => LibraryNode(x.$2, uris.uris![x.$1]!)).toList();
    final nodesById = {for (final library in mapped) library.value.id!: library};

    for (final node in nodesById.values) {
      final dependencies = node.value.dependencies!.where(isCurrentPackage.checkDependency).map((x) => nodesById[x.target!.id!]!);
      node.dependencies.addAll(dependencies);
    }

    return nodesById.values.toList();
  }
}

extension on ScriptRef {
  String get libraryId {
    final id = this.id!.split('/').take(2).join("/");
    return id;
  }

  /// Tests are not part of any package, so their uri always starts with `file:///`
  bool get isTest {
    return uri!.startsWith('file:///') && uri!.endsWith('_test.dart');
  }
}

class LibraryNode {
  final Library value;
  final List<LibraryNode> dependencies = [];

  final String fileUri;

  LibraryNode(this.value, this.fileUri);

  bool get isProbablyTest => fileUri.endsWith('_test.dart');

  String get prettyJson {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(value.json);
  }

  FileDependencies getNestedDependencies() {
    final visited = <String>{};
    void visit(LibraryNode node) {
      final uri = node.fileUri;

      if (!visited.add(uri)) {
        return;
      }

      node.dependencies.forEach(visit);
    }

    visit(this);
    return FileDependencies(fileUri, visited);
  }
}

class FileDependencies {
  final String uri;
  final Set<String> dependencies;

  FileDependencies(this.uri, this.dependencies);

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('$uri:');

    for (final dep in dependencies) {
      buffer.writeln('  - $dep');
    }
    return buffer.toString();
  }
}

class IsCurrentPackage {
  IsCurrentPackage(this._packageDirectory);

  factory IsCurrentPackage.fromScriptRefs(List<ScriptRef> scripts) {
    final uri = Uri.parse(scripts.first.uri!);

    final components = uri.pathSegments.toList();

    if (components.last.endsWith('.dart')) {
      components.removeLast();
    }

    if (components.last == 'test') {
      components.removeLast();
    }

    return IsCurrentPackage(uri.replace(pathSegments: components));
  }

  final Uri _packageDirectory;
  // only works if directory is the same as name in pubspec
  late final String packagePrefix = 'package:$packageName';

  bool call(String? uri) {
    if (uri == null) return false;
    return uri.startsWith(packagePrefix) || uri.startsWith(_packageDirectory.toString());
  }

  /// this may not always work
  String get packageName => _packageDirectory.pathSegments.last.replaceAll("-", "_");

  bool checkLibraryRef(LibraryRef ref) => call(ref.uri);
  bool checkDependency(LibraryDependency dep) => call(dep.target!.uri);
  bool checkScriptRef(ScriptRef script) => call(script.uri);
}
