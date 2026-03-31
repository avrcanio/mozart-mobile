import 'package:flutter_test/flutter_test.dart';
import 'package:mozart_mobile/src/app.dart';

void main() {
  testWidgets('renders login shell', (tester) async {
    await tester.pumpWidget(const MozartMobileApp());
    await tester.pump();

    expect(find.text('Mozart Mobile'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
