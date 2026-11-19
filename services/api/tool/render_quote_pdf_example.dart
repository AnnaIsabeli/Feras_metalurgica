import 'dart:io';
import 'package:fera_api/src/documents/quote_document.dart';
import 'package:fera_api/src/documents/quote_pdf_renderer.dart';

QuoteDocument exampleQuote({
  bool stress = false,
  bool delivery = true,
  bool empty = false,
  bool unsupported = false,
  int quantity = 1,
  int unitPriceCents = 387045,
}) => QuoteDocument(
  requestId: '12345678-1234-4234-8234-123456789012',
  pricingId: '87654321-4321-4321-8321-210987654321',
  savedAt: DateTime.utc(2026, 11, 11, 19, 30),
  customerName: 'Marina de Souza (exemplo)',
  customerEmail: 'cliente.pdf@example.invalid',
  product: unsupported ? 'Teste \u{10ffff}' : 'Portão metálico sob medida',
  quantity: quantity,
  description: stress
      ? ('Descrição com acentuação, fabricação e instalação. ' * 70)
            .padRight(4000, 'X')
            .substring(0, 4000)
      : 'Fabricação e instalação de portão metálico de correr, com estrutura em metalon, fechamento em chapa galvanizada e acabamento em pintura esmalte PU. Medidas: 3,00 m de largura por 2,20 m de altura.',
  unitPriceCents: unitPriceCents,
  deliveryLeadTime: delivery ? '20 dias úteis após a aprovação' : null,
  items: empty
      ? []
      : stress
      ? List.generate(
          100,
          (i) => QuoteDocumentItem(
            name:
                'Item ${i + 1} - material com descrição extensa e acabamento metálico '
                    .padRight(120, 'X'),
            unit: 'unidade',
            quantity: i + 1.125,
          ),
        )
      : const [
          QuoteDocumentItem(name: 'Metalon 40 x 30', unit: 'm', quantity: 6),
          QuoteDocumentItem(
            name: 'Chapa de aço galvanizado',
            unit: 'm²',
            quantity: 1.75,
          ),
          QuoteDocumentItem(name: 'Tinta esmalte PU', unit: 'L', quantity: .5),
        ],
);

Future<void> main(List<String> args) async {
  if (args.isEmpty) throw ArgumentError('Informe o arquivo PDF de saída.');
  final renderer = await QuotePdfRenderer.load();
  if (args.first == '--all' && args.length == 2) {
    await Directory(args[1]).create(recursive: true);
    for (final entry in {
      'orcamento-exemplo': exampleQuote(),
      'orcamento-longo': exampleQuote(stress: true),
      'orcamento-sem-prazo': exampleQuote(delivery: false),
      'orcamento-duas-unidades': exampleQuote(quantity: 2),
    }.entries) {
      await File(
        '${args[1]}/${entry.key}.pdf',
      ).writeAsBytes(await renderer.render(entry.value));
    }
    return;
  }
  final bytes = await renderer.render(
    exampleQuote(
      stress: args.contains('--stress'),
      delivery: !args.contains('--no-delivery'),
    ),
  );
  await File(args.first).parent.create(recursive: true);
  await File(args.first).writeAsBytes(bytes);
}
