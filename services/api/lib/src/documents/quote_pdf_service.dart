import 'dart:typed_data';
import '../auth/principal.dart';
import '../core/api_error.dart';
import '../quotes/pricing_service.dart';
import 'quote_document.dart';
import 'quote_pdf_renderer.dart';

class QuotePdfFile {
  const QuotePdfFile(this.bytes, this.filename);
  final Uint8List bytes;
  final String filename;
}

class QuotePdfService {
  QuotePdfService(this.repository, this.renderer);
  final QuoteDocumentRepository repository;
  final QuotePdfRenderer renderer;

  void authorize(Principal actor) {
    if (actor.role != UserRole.seller || !actor.sellerApproved) {
      throw const ApiError(
        403,
        'seller_required',
        'Somente vendedores aprovados podem gerar o PDF do orçamento.',
      );
    }
  }

  Future<QuotePdfFile> generate(
    Principal actor,
    String requestId, {
    String? pricingId,
  }) async {
    authorize(actor);
    if (!PricingService.uuid.hasMatch(requestId) ||
        (pricingId != null && !PricingService.uuid.hasMatch(pricingId))) {
      throw const ApiError(
        422,
        'invalid_document_id',
        'Identificação do orçamento inválida.',
      );
    }
    final document = await repository.find(requestId, pricingId: pricingId);
    if (document == null) {
      throw const ApiError(
        404,
        'pricing_not_found',
        'Salve uma precificação desta solicitação antes de gerar o PDF.',
      );
    }
    if (document.items.isEmpty) {
      throw const ApiError(
        409,
        'incomplete_pricing',
        'A precificação salva não contém itens.',
      );
    }
    return QuotePdfFile(
      await renderer.render(document),
      'orcamento-${document.requestId}-${document.pricingId}.pdf',
    );
  }
}
