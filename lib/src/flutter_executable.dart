// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports necessary for hottie use case

import 'package:flutter_tools/runner.dart' as runner;
import 'package:flutter_tools/src/base/context.dart';
import 'package:flutter_tools/src/base/io.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/base/template.dart';
import 'package:flutter_tools/src/base/terminal.dart';
import 'package:flutter_tools/src/base/user_messages.dart';
import 'package:flutter_tools/src/build_system/build_targets.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/daemon.dart';
import 'package:flutter_tools/src/commands/test.dart';
import 'package:flutter_tools/src/devtools_launcher.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
// Files in `isolated` are intentionally excluded from google3 tooling.
import 'package:flutter_tools/src/isolated/build_targets.dart';
import 'package:flutter_tools/src/isolated/mustache_template.dart';
import 'package:flutter_tools/src/isolated/native_assets/test/native_assets.dart';
import 'package:flutter_tools/src/isolated/resident_web_runner.dart';
import 'package:flutter_tools/src/native_assets.dart';
import 'package:flutter_tools/src/pre_run_validator.dart';
import 'package:flutter_tools/src/resident_runner.dart';
import 'package:flutter_tools/src/test/test_wrapper.dart';
import 'package:flutter_tools/src/web/web_runner.dart';

/// Main entry point for commands.
///
/// This function is intended to be used from the `flutter` command line tool.
Future<void> main(List<String> args, TestWrapper testWrapper) async {
  final veryVerbose = args.contains('-vv');
  final verbose = args.contains('-v') || args.contains('--verbose') || veryVerbose;
  final prefixedErrors = args.contains('--prefixed-errors');
  // Support the -? Powershell help idiom.
  final powershellHelpIndex = args.indexOf('-?');
  if (powershellHelpIndex != -1) {
    args[powershellHelpIndex] = '-h';
  }

  final doctor = (args.isNotEmpty && args.first == 'doctor') || (args.length == 2 && verbose && args.last == 'doctor');
  final help = args.contains('-h') || args.contains('--help') || (args.isNotEmpty && args.first == 'help') || (args.length == 1 && verbose);
  final muteCommandLogging = (help || doctor) && !veryVerbose;
  final verboseHelp = help && verbose;
  final daemon = args.contains('daemon');
  final runMachine = (args.contains('--machine') && args.contains('run')) ||
      (args.contains('--machine') && args.contains('attach')) ||
      // `flutter widget-preview start` starts an application that requires a logger
      // to be setup for machine mode.
      (args.contains('widget-preview') && args.contains('start'));

  // Cache.flutterRoot must be set early because other features use it (e.g.
  // enginePath's initializer uses it). This can only work with the real
  // instances of the platform or filesystem, so just use those.
  Cache.flutterRoot = Cache.defaultFlutterRoot(
    platform: const LocalPlatform(),
    fileSystem: globals.localFileSystem,
    userMessages: UserMessages(),
  );

  await runner.run(
    args,
    () => [
      TestCommand(
        verboseHelp: verboseHelp,
        verbose: verbose,
        nativeAssetsBuilder: globals.nativeAssetsBuilder,
        testWrapper: testWrapper,
      )
    ],
    verbose: verbose,
    muteCommandLogging: muteCommandLogging,
    verboseHelp: verboseHelp,
    overrides: <Type, Generator>{
      // The web runner is not supported in google3 because it depends
      // on dwds.
      WebRunnerFactory: DwdsWebRunnerFactory.new,
      // The mustache dependency is different in google3
      TemplateRenderer: () => const MustacheTemplateRenderer(),
      // The devtools launcher is not supported in google3 because it depends on
      // devtools source code.
      DevtoolsLauncher: () => DevtoolsServerLauncher(
            processManager: globals.processManager,
            artifacts: globals.artifacts!,
            logger: globals.logger,
            botDetector: globals.botDetector,
          ),
      BuildTargets: () => const BuildTargetsImpl(),
      Logger: () {
        final loggerFactory = LoggerFactory(
          outputPreferences: globals.outputPreferences,
          terminal: globals.terminal,
          stdio: globals.stdio,
        );
        return loggerFactory.createLogger(
          daemon: daemon,
          machine: runMachine,
          verbose: verbose && !muteCommandLogging,
          prefixedErrors: prefixedErrors,
          windows: globals.platform.isWindows,
        );
      },
      AnsiTerminal: () {
        return AnsiTerminal(
          stdio: globals.stdio,
          platform: globals.platform,
          now: DateTime.now(),
          // So that we don't animate anything before calling applyFeatureFlags, default
          // the animations to disabled in real apps.
          defaultCliAnimationEnabled: false,
          shutdownHooks: globals.shutdownHooks,
        );
        // runner.run calls "terminal.applyFeatureFlags()"
      },
      PreRunValidator: () => PreRunValidator(fileSystem: globals.fs),
      TestCompilerNativeAssetsBuilder: () => const TestCompilerNativeAssetsBuilderImpl(),
    },
    shutdownHooks: globals.shutdownHooks,
  );
}

/// An abstraction for instantiation of the correct logger type.
///
/// Our logger class hierarchy and runtime requirements are overly complicated.
class LoggerFactory {
  LoggerFactory({
    required Terminal terminal,
    required Stdio stdio,
    required OutputPreferences outputPreferences,
    StopwatchFactory stopwatchFactory = const StopwatchFactory(),
  })  : _terminal = terminal,
        _stdio = stdio,
        _stopwatchFactory = stopwatchFactory,
        _outputPreferences = outputPreferences;

  final Terminal _terminal;
  final Stdio _stdio;
  final StopwatchFactory _stopwatchFactory;
  final OutputPreferences _outputPreferences;

  /// Create the appropriate logger for the current platform and configuration.
  Logger createLogger({
    required bool verbose,
    required bool prefixedErrors,
    required bool machine,
    required bool daemon,
    required bool windows,
  }) {
    Logger logger;
    if (windows) {
      logger = WindowsStdoutLogger(
        terminal: _terminal,
        stdio: _stdio,
        outputPreferences: _outputPreferences,
        stopwatchFactory: _stopwatchFactory,
      );
    } else {
      logger = StdoutLogger(
        terminal: _terminal,
        stdio: _stdio,
        outputPreferences: _outputPreferences,
        stopwatchFactory: _stopwatchFactory,
      );
    }
    if (verbose) {
      logger = VerboseLogger(logger, stopwatchFactory: _stopwatchFactory);
    }
    if (prefixedErrors) {
      logger = PrefixedErrorLogger(logger);
    }
    if (daemon) {
      return NotifyingLogger(verbose: verbose, parent: logger);
    }
    if (machine) {
      return AppRunLogger(parent: logger);
    }
    return logger;
  }
}
