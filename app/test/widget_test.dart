import 'package:flutter_test/flutter_test.dart';
import 'package:nexronda/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NexRondaApp());
    expect(find.text('NexRonda'), findsOneWidget);
  });
}
