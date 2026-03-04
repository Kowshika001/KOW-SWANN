// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:love_app/main.dart';

void main() {
  testWidgets('SplashScreen displays correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the splash screen shows the title.
    expect(find.text('Love Messages'), findsOneWidget);

    // Verify that the input fields for names are present.
    expect(find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.labelText == 'Your Name'), findsOneWidget);
    expect(find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.labelText == "Your Partner's Name"), findsOneWidget);

    // Verify that the "Start Chatting" button is present.
    expect(find.text('Start Chatting'), findsOneWidget);
  });
}
