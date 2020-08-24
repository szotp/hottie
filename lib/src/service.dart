import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:hottie/src/native.dart';

import 'declarer.dart';
import 'logger.dart';
import 'model.dart';

typedef TestMain = void Function();

class TestInput {
  final SendPort fromIsolate;
  final TestMain main;

  TestInput(this.main, this.fromIsolate);
}

abstract class TestService extends ValueNotifier<TestGroupResults> {
  final void Function() main;
  final _stopwatch = Stopwatch();

  TestService(this.main) : super(const TestGroupResults());

  factory TestService.create(TestMain main, {bool isolated = false}) {
    if (isolated) {
      return _SeparateEngineService(main);
      //return _IsolatingTestService(main);
    } else {
      return _RegularTestService(main);
    }
  }

  void retest() {
    _stopwatch.reset();
    _stopwatch.start();
  }

  @protected
  void update(TestGroupResults message) {
    value = message;

    _stopwatch.stop();
    final ms = _stopwatch.elapsed.inMicroseconds / 1000;
    logHottie('$message, took ${ms}ms');
  }
}

class _SeparateEngineService extends TestService {
  final _native = NativeService.instance;

  _SeparateEngineService(void Function() main) : super(main);

  @override
  Future<void> retest() async {
    super.retest();
    final result = await _native.execute(runTestsFromRawCallback,
        PluginUtilities.getCallbackHandle(main).toRawHandle());

    if (result != null) {
      update(result);
    }
  }
}

class _RegularTestService extends TestService {
  _RegularTestService(TestMain main) : super(main);

  @override
  void retest() {
    super.retest();
    runTests(main).then(update);
  }
}

// class _IsolatingTestService extends TestService {
//   Isolate _isolate;

//   ReceivePort _fromIsolate = ReceivePort();
//   SendPort _toIsolate;

//   static void _run(TestInput input) {
//     final reloads = ReceivePort();

//     input.fromIsolate.send(reloads.sendPort);

//     reloads.listen((message) async {
//       final result = await runTests(input.main);
//       input.fromIsolate.send(result);
//     });
//   }

//   _IsolatingTestService(TestMain main) : super(main) {
//     setup();
//   }

//   void dispose() {
//     super.dispose();
//     _isolate.kill();
//   }

//   void retest() {
//     super.retest();
//     _toIsolate?.send(null);
//   }

//   void _handleMessage(message) {
//     if (message is SendPort) {
//       _toIsolate = message;
//       retest();
//     } else if (message is TestGroupResults) {
//       update(message);
//     }
//   }

//   Future<void> setup() async {
//     final input = TestInput(main, _fromIsolate.sendPort);
//     _fromIsolate.listen(_handleMessage);
//     _isolate = await Isolate.spawn(_run, input, debugName: 'hottie');
//   }
// }
