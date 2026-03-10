import 'package:chat_viewer/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatViewerApp());
    expect(find.text('ChatVault'), findsOneWidget);
  });
}
