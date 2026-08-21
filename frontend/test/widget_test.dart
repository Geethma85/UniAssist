// Basic smoke test — confirms the app builds and renders without crashing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uniassist/main.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const UniAssistApp());

    // Just confirms the widget tree built successfully.
    // Replace/expand this once login/chat screens have real logic wired up.
    expect(find.byType(UniAssistApp), findsOneWidget);
  });
}