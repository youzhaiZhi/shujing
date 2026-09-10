import 'package:flutter_test/flutter_test.dart';

import 'package:shujing/main.dart';

void main() {
  testWidgets('App renders shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ShuJingApp());
    expect(find.text('书架'), findsOneWidget);
  });
}
