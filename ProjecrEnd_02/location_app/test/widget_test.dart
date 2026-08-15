import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:location_app/page/splash_screen.dart';

void main() {
  testWidgets('splash screen shows the security guard management branding', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(find.text('Security Guard\nManagement System'), findsOneWidget);
    expect(find.text('Secure · Manage · Protect'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    expect(find.byType(SplashScreen), findsNothing);
  });
}
