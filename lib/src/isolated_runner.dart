import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:hottie/src/declarer.dart';
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

  Future<void> execute(TestMain testMain) async {
    status.value = TestStatus.starting;
    await _api.spawn('hottie', ['test']);

    final sw = Stopwatch();
    sw.start();
    await status.waitFor(TestStatus.running).timeout(const Duration(seconds: 1), onTimeout: () {
      logHottie('Trying again...');
      _api.spawn('hottie', ['test']);
    });
    sw.stop();
    logHottie(sw.elapsedMilliseconds);

    await status.waitFor(TestStatus.running).timeout(const Duration(seconds: 1), onTimeout: () {
      logHottie('Failed...');
      _api.close();
    });
  }

  void _onMessage(dynamic message) {
    final decoded = _codec.decodeMessage(message as ByteData)! as FromIsolate;

    switch (decoded) {
      case final TestStatusFromIsolate r:
        status.value = r.status;
      case final TestGroupResults r:
        assert(status.value == TestStatus.running);
        _api.close();
        status.value = TestStatus.finished;
        _onResults(r);
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

  logHottie('runInsideIsolate');
  send(TestStatusFromIsolate(status: TestStatus.running));
  logHottie('runInsideIsolate sent');

  final results = await runTests(() {
    for (final x in tests.values) {
      x();
    }
  });

  send(results);
}

extension ValueNotifierExtension<T> on ValueNotifier<T> {
  Future<void> waitFor(T value) async {
    if (this.value == value) {
      return;
    }

    final completer = Completer();

    void handler() {
      if (this.value == value) {
        removeListener(handler);
        completer.complete();
      }
    }

    addListener(handler);
    return completer.future;
  }
}
