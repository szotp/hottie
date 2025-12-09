// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports because

import 'dart:async';
import 'dart:io';

import 'package:flutter_tools/src/test/test_wrapper.dart';
import 'package:hottie/src/utils/logger.dart';
import 'package:test_core/src/executable.dart' as test;
import 'package:test_core/src/platform.dart' as test_core;
import 'package:test_core/src/platform.dart';

export 'package:test_api/backend.dart' show Runtime;

class MyTestWrapper implements TestWrapper {
  const MyTestWrapper();

  @override
  Future<void> main(List<String> args) async {
    stdin.lineMode = false;
    logger.info('waiting for key');
    await for (final _ in stdin) {
      printer.resetStopwatch();
      await test.main(args.sublist(0, 3));
      logger.info('waiting for key');
    }
  }

  @override
  void registerPlatformPlugin(
    Iterable<Runtime> runtimes,
    FutureOr<PlatformPlugin> Function() platforms,
  ) {
    test_core.registerPlatformPlugin(runtimes, () async {
      final plugin = await platforms();
      return _MyPlugin(plugin);
    });
  }
}

class _MyPlugin extends PlatformPlugin {
  _MyPlugin(this.inner);

  final PlatformPlugin inner;

  @override
  Future<RunnerSuite?> load(
    String path,
    SuitePlatform platform,
    SuiteConfiguration suiteConfig,
    Map<String, Object?> message,
  ) async {
    final suite = await inner.load(path, platform, suiteConfig, message);

    return suite;
  }
}
