import 'dart:async';
import 'dart:developer' as d;
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/services.dart';

const _channel = MethodChannel('com.szotp.Hottie');

typedef IsolatedWorker<Input, Output> = Future<Output> Function(Input);

class NativeService {
  static final instance = NativeService();

  static const fromIsolateName = 'com.szotp.Hottie.fromIsolate';
  static const toIsolateName = 'com.szotp.Hottie.toIsolate';
  ReceivePort fromIsolate = ReceivePort();
  SendPort toIsolate;

  Future<void> _initialize() async {
    toIsolate = IsolateNameServer.lookupPortByName(toIsolateName);
    final alreadyRunning = toIsolate != null;

    _registerPort(fromIsolate.sendPort, fromIsolateName);
    fromIsolate.forEach(_onMessage);

    if (!alreadyRunning) {
      final handle = PluginUtilities.getCallbackHandle(hottieInner);

      await _channel.invokeMethod(
        'initialize',
        {'handle': handle.toRawHandle()},
      );

      while (toIsolate == null) {
        toIsolate = IsolateNameServer.lookupPortByName(toIsolateName);
        await Future.delayed(const Duration(milliseconds: 10));
      }
    }
  }

  Future<O> execute<I, O>(IsolatedWorker<I, O> method, I payload) async {
    if (toIsolate == null) {
      await _initialize();
    }

    final completer = _completer = Completer<O>();
    toIsolate.send(RunnerEvent(method, payload));

    return completer.future;
  }

  Completer _completer;

  void _onMessage(message) {
    _completer?.complete(message);
    _completer = null;
  }
}

void _registerPort(SendPort port, String name) {
  var ok = IsolateNameServer.registerPortWithName(port, name);

  if (!ok) {
    ok = IsolateNameServer.removePortNameMapping(name);
    assert(ok);
    IsolateNameServer.registerPortWithName(port, name);
  }

  assert(ok);
}

@pragma('vm:entry-point')
Future<void> hottieInner() async {
  final toIsolate = ReceivePort();
  _registerPort(toIsolate.sendPort, NativeService.toIsolateName);

  await toIsolate.forEach((event) async {
    try {
      if (event is RunnerEvent) {
        final output = await event.call();
        final fromIsolate =
            IsolateNameServer.lookupPortByName(NativeService.fromIsolateName);
        assert(fromIsolate != null);
        fromIsolate.send(output);
      }
    } catch (e) {
      d.log('_runner: got error while processing $event: $e');
    }
  });
}

class RunnerEvent<I, O> {
  final IsolatedWorker<I, O> worker;
  final I payload;
  RunnerEvent(this.worker, this.payload);

  Future call() => worker(payload);
}
