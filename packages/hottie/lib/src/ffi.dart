import 'dart:ffi';

import 'package:ffi/ffi.dart';

@Native<Void Function(Pointer<Utf8>, Pointer<Utf8>)>(symbol: 'Spawn')
external void _spawn(Pointer<Utf8> entrypoint, Pointer<Utf8> route);

void spawn(String entrypoint, String route) {
  _spawn(entrypoint.toNativeUtf8(), route.toNativeUtf8());
}

class Spawner {
  static bool dispatch() {
    return false;
  }
}
