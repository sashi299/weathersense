import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Basic smoke test', (WidgetTester tester) async {
    // Build a simple widget to verify environment is working.
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Test'))));
    expect(find.text('Test'), findsOneWidget);
  });
}
