import 'dart:math';

import 'package:flutter/material.dart';
import 'model.dart';
import 'service.dart';

class TestRunner extends StatefulWidget {
  /// Must be a static method
  final VoidCallback main;
  final bool showIndicator;
  final Widget child;

  const TestRunner({
    Key key,
    @required this.child,
    @required this.main,
    this.showIndicator = true,
  }) : super(key: key);

  @override
  _TestRunnerState createState() => _TestRunnerState();
}

class _TestRunnerState extends State<TestRunner> {
  TestService service;
  bool showsOverlay = true;

  @override
  void initState() {
    super.initState();

    service = TestService.create(widget.main, isolated: true);
    service.addListener(() => setState(() {}));
    service.retest();
  }

  @override
  void dispose() {
    service.dispose();
    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();
    service.retest();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showIndicator) {
      return widget.child;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        widget.child,
        MediaQuery(
          data: MediaQueryData.fromWindow(WidgetsBinding.instance.window),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      showsOverlay = true;
                    });
                  },
                  child: TestIndicator(results: service.value),
                ),
                if (!service.value.ok && showsOverlay)
                  Positioned.fill(
                    child: TestResultsView(
                      results: service.value,
                      onClose: () {
                        setState(() {
                          showsOverlay = false;
                        });
                      },
                    ),
                  )
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class TestResultsView extends StatelessWidget {
  final TestGroupResults results;
  final VoidCallback onClose;

  const TestResultsView({Key key, this.results, this.onClose})
      : super(key: key);

  Widget _buildError(TestResultError error) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Text(error.message),
    );
  }

  Iterable<Widget> _buildItem(TestResult result) {
    return [
      Text(
        result.name,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      ),
      ...result.errors.map(_buildError),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xF0900000),
        appBar: AppBar(
          backgroundColor: const Color(0xF0900000),
          leading: CloseButton(
            onPressed: onClose,
            color: const Color(0xFFFFFF66),
          ),
        ),
        body: DefaultTextStyle(
          style: const TextStyle(color: Color(0xFFFFFF66)),
          child: ListView(
            padding: const EdgeInsets.all(8),
            children: [
              ...results.failed.map(_buildItem).expand((element) => element),
            ],
          ),
        ),
      ),
    );
  }
}

class TestIndicator extends StatelessWidget {
  final TestGroupResults results;

  const TestIndicator({Key key, this.results}) : super(key: key);

  Widget buildStatusCircle({bool ok}) {
    final color = ok ? Colors.green : Colors.red;

    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.8),
          ),
        ),
        const SizedBox(width: 8),
        Text('${results.passed.length} / ${results.totalCount}'),
      ],
    );
  }

  Widget buildContent(BuildContext context, TestGroupResults value) {
    if (value.noFailures) {
      return buildStatusCircle(ok: true);
    }

    return Row(
      children: [
        buildStatusCircle(ok: false),
        const SizedBox(width: 4),
        Text(
          value.failed.length.toString(),
          style: const TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = MediaQueryData.fromWindow(WidgetsBinding.instance.window);

    return Align(
      alignment: Alignment.bottomLeft,
      child: Container(
        margin:
            EdgeInsets.only(left: max(data.padding.bottom - 8, 4), bottom: 4),
        padding: const EdgeInsets.only(left: 4, right: 4),
        child: Builder(
          builder: (context) {
            if (results != null) {
              return buildContent(context, results);
            } else {
              return const SizedBox();
            }
          },
        ),
      ),
    );
  }
}
