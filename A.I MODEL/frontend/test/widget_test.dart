import 'package:flutter_test/flutter_test.dart';

import 'package:ai_model_frontend/main.dart';

void main() {
  testWidgets('shows the Assistant IDE', (WidgetTester tester) async {
    await tester.pumpWidget(const AiModelApp());

    expect(find.text('Assistant'), findsAtLeastNWidgets(1));
    expect(find.text('Ask Juveh anything'), findsOneWidget);
  });
}
