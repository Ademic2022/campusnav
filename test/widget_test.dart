import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('basic widget test harness works', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('OAU Navigator')),
        ),
      ),
    );

    expect(find.text('OAU Navigator'), findsOneWidget);
  });
}
