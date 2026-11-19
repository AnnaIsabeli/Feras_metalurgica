import 'package:fera_contracts/fera_contracts.dart';
import 'package:uuid/uuid.dart';
import '../auth/policy.dart';
import '../auth/principal.dart';
import '../core/api_error.dart';
import '../core/validation.dart';
import 'quote_repository.dart';

class QuoteService {
  QuoteService(this.repository);
  final QuoteRepository repository;

  Future<List<QuoteRequest>> list(Principal actor) async {
    authorize(actor, Permission.listQuotes);
    return repository.list(
      buyerId: actor.role == UserRole.buyer ? actor.id : null,
    );
  }

  /// Busca uma solicitação aplicando perfil e propriedade. Cliente só enxerga
  /// as suas; solicitação inexistente ou de outro cliente responde 404.
  Future<QuoteRequest> get(
    Principal actor,
    String id, {
    Permission permission = Permission.readQuote,
  }) async {
    authorize(actor, permission);
    final found = isUuid(id) ? await repository.find(id) : null;
    if (found == null) {
      throw const ApiError(404, 'not_found', 'Solicitação não encontrada.');
    }
    authorize(actor, permission, ownerId: found.buyerId);
    return found;
  }

  /// Ponto único de proteção do PDF: autentica, aplica perfil e propriedade.
  /// A geração do arquivo ainda não existe; quando existir, só roda depois
  /// desta checagem.
  Future<QuoteRequest> authorizePdf(Principal actor, String id) =>
      get(actor, id, permission: Permission.downloadQuotePdf);

  Future<QuoteRequest> create(Principal actor, Map<String, dynamic> data) {
    authorize(actor, Permission.createQuote);
    final product = data['product'];
    final description = data['description'];
    final quantity = data['quantity'];
    if (product is! String ||
        product.trim().isEmpty ||
        product.length > 120 ||
        description is! String ||
        description.trim().isEmpty ||
        description.length > 4000 ||
        quantity is! int ||
        quantity < 1 ||
        quantity > 10000) {
      throw const ApiError(
        422,
        'invalid_request',
        'Informe produto (até 120 caracteres), descrição (até 4000) e quantidade inteira de 1 a 10000.',
      );
    }
    // Ownership and initial status always come from the server, never from input.
    return repository.create(
      QuoteRequest(
        id: const Uuid().v4(),
        buyerId: actor.id,
        product: product.trim(),
        description: description.trim(),
        quantity: quantity,
        status: RequestStatus.received,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }
}
