import 'package:flutter_test/flutter_test.dart';
import 'package:piutang_usaha/main.dart';

void main() {
  testWidgets('Piutang Usaha app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const PiutangUsahaApp());
    expect(find.text('Piutang Usaha'), findsOneWidget);
  });
}
