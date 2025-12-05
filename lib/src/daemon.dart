#!/usr/bin/env dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:hottie/src/utils/logger.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

/// See https://github.com/flutter/flutter/blob/master/packages/flutter_tools/doc/daemon.md
class FlutterDaemon {
  late final Process process;
  late final String appId;
  late final VmService vmService;

  final _onReady = Completer<void>();
  (Completer<DaemonResult>, int)? _onResult;

  Map<String, void Function(DaemonEvent)> handlers = {};

  void Function(String)? onLine;

  Future<void> start({required String path}) async {
    handlers['app.debugPort'] = _onDebugPort;
    handlers['app.started'] = _onAppStarted;

    logger.info('Launching flutter app...');
    process = await Process.start('flutter', ['run', path, '-d', 'flutter-tester', '--no-pub', '--device-connection', 'attached', '--machine']);
    process.stderr.listen(stderr.add);
    process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(_onLine);

    return _onReady.future;
  }

  Future<void> _onLine(String line) async {
    logger.finest(line);
    final message = DaemonMessage.parse(line);

    if (message == null) {
      _onRegularText(line);
      return;
    }

    switch (message) {
      case final DaemonResult result:
        _nextId = max(_nextId, result.id + 1);
        if (_onResult?.$2 == result.id) {
          if (result is DaemonError) {
            _onResult?.$1.completeError(result.error);
          } else {
            _onResult?.$1.complete(result);
          }

          _onResult = null;
        }

      case final DaemonEvent event:
        handlers[event.event]?.call(event);
    }
  }

  void _onRegularText(String line) {
    if (onLine != null) {
      onLine?.call(line);
    } else {
      logger.fine(line);
    }
  }

  void _onAppStarted(DaemonEvent event) {
    appId = event.params['appId'] as String;
    _onReady.complete();
  }

  /// Executes once during app start.
  Future<void> _onDebugPort(DaemonEvent event) async {
    final vmUri = event.params['wsUri'] as String;
    vmService = await vmServiceConnectUri(vmUri);
    await vmService.getVersion();
  }

  Future<void> callHotReload({bool fullRestart = false}) async {
    await sendCommand('app.restart', {'appId': appId, 'debounce': true, 'fullRestart': fullRestart});
  }

  Future<DaemonResult> callServiceExtension(String methodName, Map<String, String> params) {
    return sendCommand('app.callServiceExtension', {
      'appId': appId,
      'methodName': methodName,
      'params': params,
    });
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
    logger.fine('Sending: $encoded');

    final completer = Completer<DaemonResult>();
    _onResult = (completer, id);
    process.stdin.writeln(encoded);
    return completer.future;
  }

  Future<void> waitForExit() async => stdin.map((x) => x[0] == 'q'.codeUnits[0]).first;
}

sealed class DaemonMessage {
  static DaemonMessage? parse(String line) {
    final isJson = line.startsWith('[{') && line.endsWith('}]');
    if (!isJson) {
      return null;
    }

    final decodedList = jsonDecode(line) as List;
    final decoded = decodedList.single as Map;

    final event = decoded['event'] as String?;
    if (event != null) {
      return DaemonEvent(event, decoded['params'] as Map<String, dynamic>? ?? {});
    }

    final result = decoded['result'] as Map<String, dynamic>?;
    if (result != null) {
      return DaemonResult(decoded['id'] as int, result);
    }

    final error = decoded['error'] as String?;
    if (error != null) {
      return DaemonError(decoded['id'] as int, error);
    }

    logger.severe('Unknown json response: $decoded');
    return null;
  }
}

class DaemonResult extends DaemonMessage {
  DaemonResult(this.id, this.result);

  final int id;
  final Map<String, dynamic> result;
}

class DaemonEvent extends DaemonMessage {
  DaemonEvent(this.event, this.params);

  final String event;
  final Map<String, dynamic> params;

  String? get id => params['id'] as String?;
  String? get appId => params['appId'] as String?;
  bool? get finished => params['finished'] as bool?;
}

class DaemonError extends DaemonResult {
  DaemonError(int id, this.error) : super(id, {'error': error});

  final String error;
}
