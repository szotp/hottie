# hottie

Experiment to run tests inside a running app, for faster feedback loop.

## Running example

1. Run example/lib/main_hottie.dart.
2. Notice green indicator in the bottom left corner.
3. Break some tests or tested methods. Save and hot reload.
4. See error page appearing with failed test.
5. Fix tests.
6. See that error page disappeared.

## Adding to existing project

1. Add hottie to your dev_dependencies:
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  hottie:
    git: https://github.com/szotp/hottie
```

3. Create this main_hottie.dart file in your test directory, and configure your IDE to use it.
```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hottie/hottie.dart';
import 'package:example/main.dart' as m;


Future<void> main() async {
  runApp(
    TestRunner(main: testAll, child: m.MyApp()),
  );
}

@pragma('vm:entry-point')
void hottie() => hottieInner();

void testAll() {}
```

4. Import all your test files and run them in testAll method:
```dart
import 'package:flutter/widgets.dart';
import 'package:hottie/hottie.dart';
import 'package:example/main.dart' as m;

import 'standard_test.dart' as t1;
import 'widgets_test.dart' as t2;

void main() {
  runApp(
    TestRunner(main: testAll, child: m.MyApp()),
  );
}

void testAll() {
  t1.main();
  t2.main();
}
```
5. Run your app and enjoy rapid testing.


## More examples
Provider fork with hottie: https://github.com/szotp/provider/tree/hottie
On my machine, all tests execute in below 1 second.

## Supported platforms
* macOS
* iOS simulator