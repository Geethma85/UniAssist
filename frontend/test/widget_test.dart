import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniassist/main.dart';
import 'package:uniassist/screens/login_screen.dart';

void main() {
  testWidgets('App opens the login form without accessing Firebase',
      (WidgetTester tester) async {
    await tester.pumpWidget(const UniAssistApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}