import 'package:ai_health_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  testWidgets('renders compact health shell navigation', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AiHealthApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Sog‘liq'), findsWidgets);
    expect(find.text('Qurilmalar'), findsOneWidget);
    expect(find.text('Sozlamalar'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);
    expect(find.text('Activity'), findsNothing);
  });

  testWidgets('switches visible settings labels to Russian', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AiHealthApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Sozlamalar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Rus'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Настройки'), findsWidgets);
    expect(find.text('Язык'), findsOneWidget);
    expect(find.text('Русский'), findsOneWidget);
    expect(find.text('Здоровье'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.health_and_safety_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Сон'), findsWidgets);
    expect(find.text('Пульс'), findsWidgets);
  });
}
