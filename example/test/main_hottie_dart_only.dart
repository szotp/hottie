import 'package:hottie/hottie_insider.dart';
import 'package:test/test.dart';

Future<void> main() => hottie({
      'file_2_test.dart': () {
        test('test', () {
          expect(1, 5);
        });
      },
    });
