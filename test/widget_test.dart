import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shujing/widgets/glass.dart';

void main() {
  testWidgets('GlassNavBar renders 4 tabs', (WidgetTester tester) async {
    int tapped = -1;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: GlassNavBar(
            index: 0,
            onTap: (i) => tapped = i,
            items: const [
              NavItem(Icons.home_rounded, '首页'),
              NavItem(Icons.cloud_download_rounded, '书源'),
              NavItem(Icons.pie_chart_outline_rounded, '统计'),
              NavItem(Icons.person_rounded, '我的'),
            ],
          ),
        ),
      ),
    ));
    expect(find.text('首页'), findsOneWidget);
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.pie_chart_outline_rounded));
    await tester.pump();
    expect(tapped, 2);
  });
}
