import 'dart:ffi';

import 'package:ffi/ffi.dart';

// stolen from isolate_spawning_tester generated data

@Native<Void Function(Pointer<Utf8>, Pointer<Utf8>)>(symbol: 'Spawn')
external void _spawn(Pointer<Utf8> entrypoint, Pointer<Utf8> route);
void spawn(String entryPoint, String route) => _spawn(entryPoint.toNativeUtf8(), route.toNativeUtf8());

@Native<Handle Function(Pointer<Utf8>)>(symbol: 'LoadLibraryFromKernel')
external Object _loadLibraryFromKernel(Pointer<Utf8> dillUriString);

void Function() loadLibraryFromKernel(String dillUriString) => _loadLibraryFromKernel(dillUriString.toNativeUtf8()) as void Function();

@Native<Handle Function(Pointer<Utf8>, Pointer<Utf8>)>(symbol: 'LookupEntryPoint')
external Object _lookupEntryPoint(Pointer<Utf8> dartUrl, Pointer<Utf8> name);

/// For example:
/// - dartUrl: `file:///URL_BASE/build/isolate_spawning_tester/child_test_isolate_spawner.dart`
/// - name: testMain
void Function() lookupEntryPoint(String dartUrl, String name) => _lookupEntryPoint(dartUrl.toNativeUtf8(), name.toNativeUtf8()) as void Function();
