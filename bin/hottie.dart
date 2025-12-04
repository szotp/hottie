#!/usr/bin/env dart

import 'dart:async';

import 'package:dtd/dtd.dart' as dtd;
import 'package:flutter_daemon/flutter_daemon.dart';
import 'package:hottie/src/utils/logger.dart';
import 'package:hottie/src/watch.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

/// Watches Dart files and automatically triggers hot reload by sending 'r' to flutter run
Future<void> main() => HottieFrontendNew().run();

class HottieFrontendNew {
  final daemon = FlutterDaemon();
  late final FlutterApplication app;
  late final VmService _vm;

  String? isolateId;

  Future<void> run() async {
    logger.i('Launching flutter app...');
    daemon.events.listen(_onEvent);
    app = await daemon.run(arguments: ['test/main_hottie.dart', '-d', 'flutter-tester', '--no-pub', '--device-connection', 'attached']);

    return watchDartFiles().forEach(_onFilesChanged);
  }

  Future<void> _onEvent(FlutterDaemonEvent event) async {
    switch (event.event) {
      case 'app.dtd':
        _onDevTools(event).withLogging();
      case 'hottie.registered':
        await _onHottieRegistered(event);
    }
  }

  /// Executes once during app start.
  Future<void> _onDevTools(FlutterDaemonEvent event) async {
    final uri = event.params['uri'] as String;
    final tooling = await dtd.DartToolingDaemon.connect(Uri.parse(uri));
    final services = await tooling.getVmServices();
    final vmUri = services.vmServicesInfos.single.uri;

    _vm = await vmServiceConnectUri(vmUri);
    final version = await _vm.getVersion();
    logger.t('VM connected. ${version.json}');
    await _runTests();
  }

  Future<void> _onHottieRegistered(FlutterDaemonEvent event) async {
    isolateId = event.params['isolateId'] as String;
  }

  /// Executes when any dart file changes.
  /// Causes hot reload, which eventually leads to _onIsolateReload being called.
  Future<void> _onFilesChanged(String changedFile) async {
    logger.i('_onFilesChanged: $changedFile');
    await app.restart();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await _runTests();
  }

  Future<void> _runTests() async {
    logger.i('Call extension');

    final result = await _vm.callServiceExtension('ext.hottie.test', isolateId: isolateId);
    logger.i(result);
  }
}
