import 'package:flutter_test/flutter_test.dart';
import 'package:chirotrack/main.dart';

void main() {
  testWidgets('App launches without error', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('ChiroTrack'), findsOneWidget);
  });
}
