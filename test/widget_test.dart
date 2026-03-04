import 'package:flutter_test/flutter_test.dart';
import 'package:chat_viewer/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatViewerApp());
    expect(find.text('Chat Viewer'), findsOneWidget);
  });
}
