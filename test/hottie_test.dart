import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hottie/hottie.dart';

void main() {
  const MethodChannel channel = MethodChannel('hottie');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await Hottie.platformVersion, '42');
  });
}
