class TestResult {
  final String name;
  final List<TestResultError> errors;

  TestResult(this.name, this.errors);
}

class TestResultError {
  final String message;

  TestResultError(this.message);
}

class TestGroupResults {
  final int skipped;
  final List<TestResult> failed;
  final List<TestResult> passed;

  int get totalCount => passed.length + failed.length + skipped;
  int get passedCount => passed.length;

  bool get noFailures => failed.isEmpty;

  const TestGroupResults({
    this.skipped = 0,
    this.failed = const [],
    this.passed = const [],
  });

  bool get ok => noFailures;

  @override
  String toString() {
    return '🧪 $passedCount / $totalCount';
  }
}
