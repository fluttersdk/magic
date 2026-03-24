import 'package:flutter_test/flutter_test.dart';
import 'package:magic/magic.dart';

void main() {
  testWidgets('Magic app boots smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MagicApplication(
        title: 'Test App',
      ),
    );

    expect(find.byType(MagicApplication), findsOneWidget);
  });
}
  