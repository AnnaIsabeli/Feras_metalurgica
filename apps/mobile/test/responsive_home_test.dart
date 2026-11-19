import 'package:fera_mobile/features/home_screen.dart';
import 'package:fera_mobile/features/quotes/quote_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'quote_view_model_test.dart' show FakeQuotes;

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(1280, 720),
    const Size(1920, 1080),
  ]) {
    testWidgets(
      'home adapts at ${size.width} without nested narrow scrolling',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final model = QuoteViewModel(FakeQuotes());
        addTearDown(model.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              appBar: AppBar(),
              bottomNavigationBar: const SizedBox(height: 76),
              body: HomeScreen(
                model: model,
                seller: true,
                onCreate: () {},
                onList: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final label in ['Criar orçamento', 'Visualizar orçamentos']) {
          final wordStart = label.indexOf('orçamento');
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(label),
          );
          expect(
            paragraph.getBoxesForSelection(
              TextSelection(baseOffset: wordStart, extentOffset: label.length),
            ),
            hasLength(1),
            reason: 'Do not split the word orçamento across lines',
          );
        }

        final scroll = tester.getRect(find.byKey(const Key('homeScroll')));
        expect(scroll.width, size.width);
        if (size.width >= 1000) {
          final greeting = tester.getRect(find.text('Olá!'));
          final carousel = tester.getRect(find.byType(ProjectCarousel));
          expect(carousel.left, greaterThan(greeting.right));
          expect(carousel.bottom, lessThanOrEqualTo(size.height - 76));
        }
      },
    );
  }
}
