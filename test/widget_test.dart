import 'package:ai_health_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  testWidgets('renders app shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AiHealthApp()));
    await tester.pump();

    expect(find.text('AI Health'), findsWidgets);
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
