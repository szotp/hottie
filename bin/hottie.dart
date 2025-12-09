#!/usr/bin/env dart
// ignore_for_file: avoid_print user interaction

import 'dart:async';

import 'package:hottie/src/flutter_executable.dart' as executable;
import 'package:hottie/src/test_wrapper.dart';

Future<void> main(List<String> arguments) async {
  await executable.main(arguments, const HottieTestWrapper());
}
