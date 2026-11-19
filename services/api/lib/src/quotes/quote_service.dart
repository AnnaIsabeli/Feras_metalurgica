import 'package:fera_contracts/fera_contracts.dart';
import 'package:uuid/uuid.dart';
import '../auth/principal.dart';
import '../auth/policy.dart';
import '../core/validation.dart';
import '../core/api_error.dart';
import 'quote_repository.dart';

class QuoteService {
  QuoteService(this.repository);
  final QuoteRepository repository;

  Future<List<QuoteRequest>> list(Principal actor) {
    authorize(actor, Permission.listQuotes);
    return repository.list(
      buyerId: actor.role == UserRole.buyer ? actor.id : null,
    );
  }

  /// Consulta individual com isolamento por proprietário. IDs inválidos e
  /// recursos inexistentes não chegam ao PostgreSQL.
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

  Future<QuoteRequest> authorizePdf(Principal actor, String id) =>
      get(actor, id, permission: Permission.downloadQuotePdf);

  Future<QuoteRequest> create(Principal actor, Map<String, dynamic> data) {
    final seller = actor.role == UserRole.seller;
    if (seller && !actor.sellerApproved) {
      throw const ApiError(
        403,
        'seller_approval_required',
        'Aguarde a aprovação do seu acesso de vendedor.',
      );
    }
    final customerName = seller ? data['customerName'] : null;
    final customerContact = seller ? data['customerContact'] : null;
    if (seller &&
        (customerName is! String ||
            customerName.trim().isEmpty ||
            customerName.length > 120 ||
            (customerContact != null &&
                (customerContact is! String ||
                    customerContact.length > 120)))) {
      throw const ApiError(
        422,
        'invalid_customer',
        'Informe o nome do cliente (até 120 caracteres) e um contato opcional de até 120 caracteres.',
      );
    }
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
        buyerId: seller ? null : actor.id,
        createdBy: actor.id,
        customerName: customerName is String ? customerName.trim() : null,
        customerContact:
            customerContact is String && customerContact.trim().isNotEmpty
            ? customerContact.trim()
            : null,
        product: product.trim(),
        description: description.trim(),
        quantity: quantity,
        status: RequestStatus.received,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }
}
