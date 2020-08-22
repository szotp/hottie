library hottie;

import 'dart:math';

import 'package:flutter/material.dart';
import 'src/model.dart';
import 'src/service.dart';

class TestRunner extends StatefulWidget {
  /// Must be a static method
  final VoidCallback main;
  final bool showIndicator;
  final Widget child;

  const TestRunner({Key key, this.child, this.main, this.showIndicator = true})
      : super(key: key);

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
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      ),
      ...result.errors.map(_buildError),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DefaultTextStyle(
        style: TextStyle(color: Colors.black),
        child: Scaffold(
          appBar: AppBar(
            leading: CloseButton(
              onPressed: onClose,
            ),
          ),
          // appBar: PreferredSize(
          //   child: Container(
          //     color: Color(0xF0900000),
          //     alignment: Alignment.bottomCenter,
          //     padding: EdgeInsets.only(bottom: 8),
          //     child: Text(
          //       'TESTS FAILED',
          //       style: TextStyle(
          //         fontSize: 16,
          //         fontWeight: FontWeight.bold,
          //         color: Color(0xFFFFFF66),
          //       ),
          //     ),
          //   ),
          //   preferredSize: Size(50, 50),
          // ),
          body: DefaultTextStyle(
            style: TextStyle(color: Colors.black),
            child: ListView(
              padding: EdgeInsets.all(8),
              children: [
                ...results.failed.map(_buildItem).expand((element) => element),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TestIndicator extends StatelessWidget {
  final TestGroupResults results;

  const TestIndicator({Key key, this.results}) : super(key: key);

  Widget buildStatusCircle(bool ok) {
    final color = ok ? Colors.green : Colors.red;

    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.8),
      ),
    );
  }

  Widget buildContent(BuildContext context, TestGroupResults value) {
    if (value.noFailures) {
      return buildStatusCircle(true);
    }

    return Row(
      children: [
        buildStatusCircle(false),
        SizedBox(width: 4),
        Text(
          value.failed.length.toString(),
          style: TextStyle(
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
        padding: EdgeInsets.only(left: 4, right: 4),
        child: Builder(
          builder: (context) {
            if (results != null) {
              return buildContent(context, results);
            } else {
              return SizedBox();
            }
          },
        ),
      ),
    );
  }
}
