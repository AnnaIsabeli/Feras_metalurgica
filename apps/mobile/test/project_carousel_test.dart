import 'package:fera_mobile/features/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'carousel has manual navigation and no overflow on small screens',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ProjectCarousel())),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Mesa com estrutura metálica e tampo de madeira'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Próxima imagem'));
      await tester.pumpAndSettle();
      expect(find.text('Suportes metálicos para plantas'), findsOneWidget);
      await tester.tap(find.byTooltip('Ver imagem 3'));
      await tester.pumpAndSettle();
      expect(
        find.text('Mesa e estante com estrutura metálica'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
