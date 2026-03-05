import 'package:flutter_test/flutter_test.dart';

import 'package:love_app/main.dart';

void main() {
  testWidgets('App root renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Love Messages'), findsOneWidget);
  });
}
