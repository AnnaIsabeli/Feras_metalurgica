import 'package:fera_mobile/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('production default does not expose demonstration login', (
    tester,
  ) async {
    await tester.pumpWidget(const FeraApp());
    expect(find.text('Bem-vindo ao ORCEX'), findsOneWidget);
    expect(find.text('Demonstração: vendedor'), findsNothing);
  });
}
