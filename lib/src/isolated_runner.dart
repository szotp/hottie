import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:hottie/src/declarer.dart';
import 'package:hottie/src/dependency_finder.dart';
import 'package:hottie/src/logger.dart';
import 'package:hottie/src/model.g.dart';

const _codec = SpawnHostApi.pigeonChannelCodec;
const _onResultsPort = 'IsolatedRunnerService._onResults';

class IsolatedRunnerService {
  final void Function(TestGroupResults) _onResults;
  final _api = SpawnHostApi();
  final _port = ReceivePort();

  final status = ValueNotifier(TestStatus.starting);

  IsolatedRunnerService(this._onResults) {
    _registerPort(_port.sendPort, _onResultsPort);
    _port.forEach(_onMessage);
  }

  Future<void> respawn() async {
    status.value = TestStatus.starting;
    await _api.spawn('hottie', ['test']);

    final sw = Stopwatch();
    sw.start();
    await status.waitFor((x) => x != TestStatus.starting).timeout(const Duration(seconds: 1), onTimeout: () {
      logHottie('Trying again...');
      _api.spawn('hottie', ['test']);
    });
    sw.stop();

    await status.waitFor((x) => x != TestStatus.starting).timeout(const Duration(seconds: 1), onTimeout: () {
      logHottie('Failed...');
      _api.close();
    });
  }

  void _onMessage(dynamic message) {
    final decoded = _codec.decodeMessage(message as ByteData)! as FromIsolate;

    switch (decoded) {
      case final TestStatusFromIsolate r:
        status.value = r.status;
        logHottie(status.toString());

      case final TestGroupResults r:
        _onResults(r);
        status.value = TestStatus.finished;
        logHottie(status.toString());
        respawn();
    }
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

Future<void> runInsideIsolate(List<String> args, Map<String, TestMain> tests) async {
  final port = IsolateNameServer.lookupPortByName(_onResultsPort)!;
  void send(FromIsolate message) => port.send(_codec.encodeMessage(message));

  send(TestStatusFromIsolate(status: TestStatus.waiting));

  final observer = ScriptChangeObserver();
  await observer.connect();

  await observer.waitForReload();
  logHottie('Hot reload detected!');
  await Future.delayed(const Duration(milliseconds: 100));
  final sw = Stopwatch()..start();
  final files = await observer.checkLibraries();
  observer.dispose();
  logHottie('runInsideIsolate ${files.length} ${sw.elapsedMilliseconds}ms');
  send(TestStatusFromIsolate(status: TestStatus.running));

  final results = await runTests(() {
    for (final testFunc in tests.values) {
      testFunc();
    }
  });

  logHottie('runInsideIsolate X ${sw.elapsedMilliseconds}ms');
  send(results);
  Isolate.exit();
}

extension ValueNotifierExtension<T> on ValueNotifier<T> {
  Future<void> waitFor(bool Function(T) isReady) async {
    if (isReady(value)) {
      return;
    }

    final completer = Completer();

    void handler() {
      if (isReady(value)) {
        removeListener(handler);
        completer.complete();
      }
    }

    addListener(handler);
    return completer.future;
  }
}
