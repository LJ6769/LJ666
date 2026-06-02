import 'package:flutter_test/flutter_test.dart';

import 'package:hilmi/main.dart';

void main() {
  testWidgets('shows splash then home content', (WidgetTester tester) async {
    await tester.pumpWidget(const HilmiApp());

    expect(find.text('Hilmi'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump();

    expect(find.text('0'), findsOneWidget);
    expect(find.text('See All'), findsWidgets);
    expect(find.textContaining('placeholder'), findsWidgets);
  });
}
