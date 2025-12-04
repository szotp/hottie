#!/usr/bin/env dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:hottie/src/utils/logger.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

class FlutterDaemon {
  late final Process process;
  late final String appId;
  late final String isolateId;
  late final VmService vmService;

  final _onReady = Completer<void>();
  (Completer<DaemonResult>, int)? _onResult;

  Future<void> start() async {
    logger.i('Launching flutter app...');
    process =
        await Process.start('flutter', ['run', 'test/main_hottie.dart', '-d', 'flutter-tester', '--no-pub', '--device-connection', 'attached', '--machine']);
    process.stderr.listen(stderr.add);
    process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(_onLine);

    return _onReady.future;
  }

  Future<void> _onLine(String line) async {
    final message = _Message.parse(line);
    stdout.writeln(line);

    if (message == null) {
      return;
    }

    switch (message) {
      case final DaemonResult result:
        _nextId = max(_nextId, result.id + 1);
        if (_onResult?.$2 == result.id) {
          _onResult?.$1.complete(result);
          _onResult = null;
        }

      case final _Event event:
        switch (event.event) {
          case 'app.debugPort':
            _onDebugPort(event).withLogging();
          case 'hottie.registered':
            isolateId = event.params['isolateId'] as String;
          case 'app.started':
            _onAppStarted(event);
        }
    }
  }

  void _onAppStarted(_Event event) {
    appId = event.params['appId'] as String;
    _onReady.complete();
  }

  /// Executes once during app start.
  Future<void> _onDebugPort(_Event event) async {
    final vmUri = event.params['wsUri'] as String;
    final vm = await vmServiceConnectUri(vmUri);
    final _ = await vm.getVersion();
    vmService = vm;
  }

  Future<void> callHotReload() async {
    await sendCommand('app.restart', {'appId': appId});
  }

  int _nextId = 1;

  Future<DaemonResult> sendCommand(String name, Map<String, dynamic> params) {
    final id = _nextId++;
    final map = {
      'id': id,
      'method': name,
      'params': params,
    };

    final encoded = json.encode([map]);
    logger.t('Sending: $encoded');

    final completer = Completer<DaemonResult>();
    _onResult = (completer, id);
    process.stdin.writeln(encoded);
    return completer.future;
  }
}

sealed class _Message {
  static _Message? parse(String line) {
    final isJson = line.startsWith('[{') && line.endsWith('}]');
    if (!isJson) {
      return null;
    }

    final decodedList = jsonDecode(line) as List;
    final decoded = decodedList.single as Map;

    final event = decoded['event'] as String?;
    if (event != null) {
      return _Event(event, decoded['params'] as Map<String, dynamic>);
    }

    final result = decoded['result'] as Map<String, dynamic>?;
    if (result != null) {
      return DaemonResult(decoded['id'] as int, result);
    }

    logger.e('Unknown json response: $decoded');
    return null;
  }
}

class DaemonResult extends _Message {
  DaemonResult(this.id, this.result);

  final int id;
  final Map<String, dynamic> result;
}

/// See https://github.com/flutter/flutter/blob/master/packages/flutter_tools/doc/daemon.md
class _Event extends _Message {
  _Event(this.event, this.params);

  final String event;
  final Map<String, dynamic> params;

  String? get id => params['id'] as String?;
  String? get appId => params['appId'] as String?;
  bool? get finished => params['finished'] as bool?;
}
