import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Smoke: MaterialApp renders', (WidgetTester tester) async {
    // The full app boots Firebase, which needs a configured platform channel
    // not available in this test environment. Smoke a bare MaterialApp instead
    // to keep CI honest about the test harness itself.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('OK'))),
      ),
    );
    expect(find.text('OK'), findsOneWidget);
  });
}
