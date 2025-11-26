import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:hottie/src/declarer.dart';
import 'package:hottie/src/logger.dart';
import 'package:hottie/src/model.g.dart';
import 'package:hottie/src/service.dart';

const _codec = IsolateStarted.pigeonChannelCodec;
const _channel = MethodChannel('com.szotp.Hottie');

class NativeService {
  // ignore: unreachable_from_main
  static final instance = NativeService();

  static const fromIsolateName = 'com.szotp.Hottie.fromIsolate';
  static const toIsolateName = 'com.szotp.Hottie.toIsolate';
  ReceivePort fromIsolate = ReceivePort();
  SendPort? toIsolate;

  Future<void> _initialize() async {
    toIsolate = IsolateNameServer.lookupPortByName(toIsolateName);
    final alreadyRunning = toIsolate != null;

    _registerPort(fromIsolate.sendPort, fromIsolateName);
    fromIsolate.forEach(_onMessage);

    if (!alreadyRunning) {
      final handle = PluginUtilities.getCallbackHandle(hottieInner)!;

      final Map results = await _channel.invokeMethod(
        'initialize',
        {'handle': handle.toRawHandle()},
      ) as Map;

      final root = results["root"] as String?;

      while (toIsolate == null) {
        toIsolate = IsolateNameServer.lookupPortByName(toIsolateName);
        await Future.delayed(const Duration(milliseconds: 10));
      }

      if (root != null) {
        final msg = SetCurrentDirectoryIsolateMessage(root: root);
        _send(msg);

        assert(Directory(msg.root).existsSync(), "Directory ${msg.root} doesn't exist");
      } else {
        logHottie('running without file access');
      }
    }
  }

  void _send(IsolateMessage message) {
    toIsolate?.send(_codec.encodeMessage(message));
  }

  // ignore: unreachable_from_main
  Future<TestGroupResults> execute(TestMain testMain) async {
    if (toIsolate == null) {
      await _initialize();
    }

    final completer = Completer<ByteData>();
    _completer?.complete(null);
    _completer = completer;
    _send(RunTestsIsolateMessage(rawHandle: PluginUtilities.getCallbackHandle(testMain)!.toRawHandle()));

    final data = await completer.future;
    return _codec.decodeMessage(data)! as TestGroupResults;
  }

  Completer? _completer;

  void _onMessage(dynamic message) {
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
  PlatformDispatcher.instance.setIsolateDebugName('hottie');
  final toIsolate = ReceivePort();
  _registerPort(toIsolate.sendPort, NativeService.toIsolateName);

  // for unclear reasons, this delay is needed to prevent errors from pausing the isolate
  if (Platform.isMacOS) {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  await toIsolate.forEach((event) async {
    try {
      final message = _codec.decodeMessage(event as ByteData)! as IsolateMessage;

      switch (message) {
        case RunTestsIsolateMessage():
          final output = await runTests(message.call);
          final fromIsolate = IsolateNameServer.lookupPortByName(NativeService.fromIsolateName);
          assert(fromIsolate != null);
          fromIsolate!.send(_codec.encodeMessage(output));
        case SetCurrentDirectoryIsolateMessage():
          setTestDirectory(message.root);
      }
    } catch (e) {
      logHottie('_runner: got error while processing $event: $e');
    }
  });
}

extension on RunTestsIsolateMessage {
  void call() {
    final func = PluginUtilities.getCallbackFromHandle(CallbackHandle.fromRawHandle(rawHandle))! as TestMain;
    func();
  }
}
