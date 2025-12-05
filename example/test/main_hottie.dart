import 'package:hottie/hottie_insider.dart';

import 'file_1_test.dart' as f1;
import 'file_2_test.dart' as f2;

Future<void> main() => hottie({
      'file_1_test.dart': f1.main,
      'file_2_test.dart': f2.main,
    });
