import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'quote_document.dart';
import '../core/api_error.dart';

class QuotePdfRenderer {
  QuotePdfRenderer._(this.regular, this.bold);
  final pw.Font regular;
  final pw.Font bold;
  static Future<QuotePdfRenderer> load({
    String fontDirectory = 'assets/fonts',
  }) async => QuotePdfRenderer._(
    pw.Font.ttf(
      ByteData.sublistView(
        await File('$fontDirectory/DejaVuSans.ttf').readAsBytes(),
      ),
    ),
    pw.Font.ttf(
      ByteData.sublistView(
        await File('$fontDirectory/DejaVuSans-Bold.ttf').readAsBytes(),
      ),
    ),
  );

  static String money(int cents) {
    final whole = (cents ~/ 100).toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
    return 'R\$ $whole,${(cents % 100).toString().padLeft(2, '0')}';
  }

  static String amount(num quantity) => quantity
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'\.?0+$'), '')
      .replaceAll('.', ',');

  String _text(String input) => input
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('\t', '    ')
      .replaceAll(RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]'), '');

  // Bounded blocks allow even a 4000-character description to span pages.
  List<String> _paragraphs(String text) {
    final result = <String>[];
    for (final line in _text(text).split('\n')) {
      var remaining = line.trim();
      while (remaining.length > 380) {
        var split = remaining.lastIndexOf(' ', 380);
        if (split < 150) split = 380;
        // Do not cut UTF-16 surrogate pairs.
        if (remaining.codeUnitAt(split - 1) >= 0xd800 &&
            remaining.codeUnitAt(split - 1) <= 0xdbff) {
          split--;
        }
        result.add(remaining.substring(0, split));
        remaining = remaining.substring(split).trimLeft();
      }
      if (remaining.isNotEmpty) result.add(remaining);
    }
    return result;
  }

  Future<Uint8List> render(QuoteDocument quote) async {
    final ink = PdfColor.fromHex('#162533');
    final muted = PdfColor.fromHex('#536571');
    final accent = PdfColor.fromHex('#C25225');
    final light = PdfColor.fromHex('#F1F4F6');
    final saved = quote.savedAt.toUtc().subtract(const Duration(hours: 3));
    final date =
        '${saved.day.toString().padLeft(2, '0')}/${saved.month.toString().padLeft(2, '0')}/${saved.year}';
    final doc = pw.Document(
      title: 'Orçamento ${quote.requestId}',
      author: 'Fera Metalúrgica',
      creator: 'Orcex',
      compress: true,
    );
    final fontContext = pw.Context(document: doc.document);
    final supportedFonts = [
      regular.getFont(fontContext),
      bold.getFont(fontContext),
    ];
    final publicTexts = [
      quote.customerName,
      quote.customerEmail,
      quote.product,
      quote.description,
      ?quote.deliveryLeadTime,
      ...quote.items.expand((item) => [item.name, item.unit]),
    ];
    for (final text in publicTexts) {
      if (_text(text).runes.any(
        (rune) =>
            rune > 32 &&
            supportedFonts.any((font) => !font.isRuneSupported(rune)),
      )) {
        throw const ApiError(
          422,
          'unsupported_pdf_character',
          'Um dos textos contém caracteres não suportados pela fonte do PDF. Revise o texto antes de exportar.',
        );
      }
    }
    pw.Widget label(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 16, bottom: 7),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: accent,
        ),
      ),
    );
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(42, 36, 42, 36),
        maxPages: 30,
        theme: pw.ThemeData.withFont(base: regular, bold: bold).copyWith(
          defaultTextStyle: pw.TextStyle(
            fontSize: 10,
            color: ink,
            lineSpacing: 3,
          ),
        ),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 14),
          margin: const pw.EdgeInsets.only(bottom: 10),
          decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: accent, width: 2)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'FERA METALÚRGICA',
                    style: pw.TextStyle(
                      fontSize: 17,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'ORÇAMENTO',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: muted,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    '#${quote.requestId.substring(0, 8).toUpperCase()}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Revisão de $date',
                    style: pw.TextStyle(fontSize: 8, color: muted),
                  ),
                ],
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 9),
          margin: const pw.EdgeInsets.only(top: 12),
          decoration: pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Orcex | Revisão ${quote.pricingId}',
                style: pw.TextStyle(fontSize: 6.5, color: muted),
              ),
              pw.Text(
                '${context.pageNumber} / ${context.pagesCount}',
                style: pw.TextStyle(fontSize: 8, color: muted),
              ),
            ],
          ),
        ),
        build: (context) => [
          label('CLIENTE'),
          pw.Text(
            _text(quote.customerName),
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            _text(quote.customerEmail),
            style: pw.TextStyle(color: muted),
          ),
          label('SOLICITAÇÃO'),
          pw.Text(
            _text(quote.product),
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Quantidade solicitada: ${quote.quantity} unidade(s)',
            style: pw.TextStyle(color: muted),
          ),
          pw.SizedBox(height: 8),
          ..._paragraphs(quote.description).map(
            (part) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Text(part),
            ),
          ),
          pw.NewPage(freeSpace: 90),
          label('ITENS DO ORÇAMENTO'),
          pw.TableHelper.fromTextArray(
            context: context,
            headers: ['Descrição', 'Quantidade', 'Unidade'],
            data: quote.items
                .map(
                  (item) => [
                    _text(item.name),
                    amount(item.quantity),
                    _text(item.unit),
                  ],
                )
                .toList(),
            columnWidths: {
              0: const pw.FlexColumnWidth(6),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(1.5),
            },
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: ink),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 6,
            ),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerLeft,
            },
            oddRowDecoration: pw.BoxDecoration(color: light),
            border: null,
          ),
          pw.Container(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(height: 18),
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(color: light),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'VALOR TOTAL',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        money(quote.totalPriceCents),
                        style: pw.TextStyle(
                          fontSize: 22,
                          color: accent,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (quote.deliveryLeadTime != null) ...[
                  label('PRAZO DE ENTREGA'),
                  pw.Text(_text(quote.deliveryLeadTime!)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    return doc.save();
  }
}
