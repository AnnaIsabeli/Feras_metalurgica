import 'package:fera_contracts/fera_contracts.dart';
import 'package:uuid/uuid.dart';
import '../auth/principal.dart';
import '../core/api_error.dart';
import 'quote_repository.dart';

class QuoteService {
  QuoteService(this.repository);
  final QuoteRepository repository;

  Future<List<QuoteRequest>> list(Principal actor) {
    if (actor.role == UserRole.seller && !actor.sellerApproved) {
      throw const ApiError(
        403,
        'seller_not_approved',
        'Acesso de vendedor não aprovado.',
      );
    }
    return repository.list(
      buyerId: actor.role == UserRole.buyer ? actor.id : null,
    );
  }

  Future<QuoteRequest> create(Principal actor, Map<String, dynamic> data) {
    if (actor.role != UserRole.buyer) {
      throw const ApiError(
        403,
        'buyer_required',
        'Somente compradores criam solicitações.',
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
