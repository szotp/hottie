import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:ui';

import 'package:ffi/ffi.dart';

import 'utils/logger.dart';

@Native<Void Function(Pointer<Utf8>, Pointer<Utf8>)>(symbol: 'Spawn')
external void _ffiSpawn(Pointer<Utf8> entrypoint, Pointer<Utf8> route);

void _spawn(String entrypoint, String route) {
  _ffiSpawn(entrypoint.toNativeUtf8(), route.toNativeUtf8());
}

var _counter = 0;

class Spawn<Input, Output> {
  const Spawn(this.function);
  static const _portPrefix = 'port_spawn';

  final Future<Output> Function(Future<Input>) function;

  Future<Output> compute(Future<Input> arg) async {
    final portName = '$_portPrefix${_counter++}';
    final port = ReceivePort();
    IsolateNameServer.removePortNameMapping(portName);
    final registered = IsolateNameServer.registerPortWithName(port.sendPort, portName);
    assert(registered, 'Failed to register port $portName');
    final portCompleter = Completer<SendPort>();
    final resultsCompleter = Completer<Output>();

    port.forEach((message) async {
      if (message is SendPort) {
        portCompleter.complete(message);
        print('port received');
        message.send(await arg);
      } else if (message is Output) {
        resultsCompleter.complete(message);
      } else {
        logger.warning('Unknown message $message in spawn');
      }
    }).withLogging();

    _spawn('main', portName);

    print('waiting for port');
    try {
      try {
        await portCompleter.future.timeout(const Duration(seconds: 900));
      } catch (_) {
        // in case user added a breakpoint
        await portCompleter.future.timeout(const Duration(milliseconds: 100));
      }

      final result = await resultsCompleter.future;
      return result;
    } finally {
      IsolateNameServer.removePortNameMapping(portName);
    }
  }

  Future<bool> runIfIsolate() async {
    final routeName = PlatformDispatcher.instance.defaultRouteName;
    if (!routeName.startsWith(_portPrefix)) {
      return false;
    }

    final port = IsolateNameServer.lookupPortByName(routeName);

    if (port == null) {
      logger.warning('Port $routeName is not available');
      return true;
    }

    final receivePort = ReceivePort();
    port.send(receivePort.sendPort);

    final input = receivePort.first.then((x) => x as Input);
    final results = await function(input);
    port.send(results);
    return true;
  }
}
