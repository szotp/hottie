# hottie

Experiment to run tests inside a running app, greatly improving test feedback loop.

# Running example

1. Run example/lib/main_hottie.dart.
2. Notice green indicator in the bottom left corner.
3. Break some tests or tested methods. Save and hot reload.
4. See error page appearing with failed test.
5. Fix tests.
6. See that error page disappeared.

# Adding to existing project

1. Add hottie to your dev_dependencies:
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  hottie:
    git: https://github.com/szotp/hottie
```
2. Move your test directory to the lib. This is necessary to be able to import your test files later.

3. If you have multiple test files, create a new file in your test directory, and combine all other tests:
```dart
import 'test1.dart' as test1;
import 'test2.dart' as test2;

void main() {
  test1.main();
  test2.main();
}
```

4. Create new main_hottie.dart file, import hottie, your primary main file and test file, and wrap your App widget with TestRunner widget:
```dart
import 'package:flutter/widgets.dart';

import 'main.dart' as m;
import 'package:hottie/hottie.dart';
import 'test/test.dart' as t;

void main() {
  runApp(
    TestRunner(main: t.main, child: m.MyApp()),
  );
}

```
5. Run your app and enjoy rapid testing.

6. To run tests from command line, simply point flutter to the correct file:
```
flutter test lib/test/test.dart
```