import 'package:fera_contracts/fera_contracts.dart';
import 'package:uuid/uuid.dart';
import '../auth/principal.dart';
import '../core/api_error.dart';
import 'quote_repository.dart';

class QuoteService {
  QuoteService(this.repository);
  final QuoteRepository repository;

  Future<List<QuoteRequest>> list(
    Principal actor, {
    Map<String, String> filters = const {},
  }) {
    if (actor.role == UserRole.seller && !actor.sellerApproved) {
      throw const ApiError(
        403,
        'seller_not_approved',
        'Acesso de vendedor não aprovado.',
      );
    }
    final customer = filters['customer']?.trim();
    if (customer != null && customer.length > 120) {
      throw const ApiError(
        422,
        'invalid_filter',
        'O nome do cliente deve ter até 120 caracteres.',
      );
    }
    for (final key in ['from', 'to']) {
      final value = filters[key];
      if (value != null && (!_date(value))) {
        throw const ApiError(
          422,
          'invalid_filter',
          'Informe uma data válida no formato ano-mês-dia.',
        );
      }
    }
    if (filters['from'] != null &&
        filters['to'] != null &&
        filters['from']!.compareTo(filters['to']!) > 0) {
      throw const ApiError(
        422,
        'invalid_filter',
        'A data inicial deve ser anterior à final.',
      );
    }
    if (filters['status'] != null &&
        !RequestStatus.values.any((s) => s.name == filters['status'])) {
      throw const ApiError(422, 'invalid_filter', 'Status inválido.');
    }
    return repository.list(
      buyerId: actor.role == UserRole.buyer ? actor.id : null,
      customer: customer?.isEmpty == true ? null : customer,
      from: filters['from'],
      to: filters['to'],
      status: filters['status'],
    );
  }

  bool _date(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
    final parsed = DateTime.tryParse(value);
    return parsed != null && parsed.toIso8601String().startsWith(value);
  }

  Future<QuoteRequest> get(Principal actor, String id) async {
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id)) {
      throw const ApiError(422, 'invalid_quote', 'Orçamento inválido.');
    }
    if (actor.role == UserRole.seller && !actor.sellerApproved) {
      throw const ApiError(403, 'seller_required', 'Acesso não aprovado.');
    }
    final quote = await repository.find(id);
    if (quote == null ||
        (actor.role == UserRole.buyer && quote.buyerId != actor.id)) {
      throw const ApiError(404, 'quote_not_found', 'Orçamento não encontrado.');
    }
    return quote;
  }

  static const transitions = <String, Set<String>>{
    'pending': {'approved', 'rejected', 'cancelled'},
    'approved': {'inProduction', 'cancelled'},
    'inProduction': {'completed', 'cancelled'},
    'rejected': {'cancelled'},
  };
  Future<QuoteRequest> changeStatus(
    Principal actor,
    String id,
    Map<String, dynamic> data,
  ) async {
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id)) {
      throw const ApiError(422, 'invalid_quote', 'Orçamento inválido.');
    }
    if (actor.role == UserRole.seller && !actor.sellerApproved) {
      throw const ApiError(
        403,
        'seller_required',
        'Acesso de vendedor não aprovado.',
      );
    }
    final quote = await repository.find(id);
    if (quote == null ||
        (actor.role == UserRole.buyer && quote.buyerId != actor.id)) {
      throw const ApiError(404, 'quote_not_found', 'Orçamento não encontrado.');
    }
    final target = data['status'];
    final expected = data['expectedStatus'];
    if (quote.pricingId == null ||
        data['expectedPricingId'] != quote.pricingId) {
      throw const ApiError(
        409,
        'pricing_changed',
        'Os valores do orçamento mudaram. Atualize antes de confirmar.',
      );
    }
    if (target is! String || expected is! String) {
      throw const ApiError(
        422,
        'invalid_status',
        'Informe o status e a versão atual do orçamento.',
      );
    }
    if (quote.status.name != expected) {
      throw const ApiError(
        409,
        'status_changed',
        'O status mudou. Atualize o orçamento antes de continuar.',
      );
    }
    if (actor.role == UserRole.buyer &&
        !(quote.status == RequestStatus.pending &&
            ['approved', 'rejected'].contains(target))) {
      throw const ApiError(
        403,
        'seller_required',
        'Esta operação pertence à equipe.',
      );
    }
    if (!(transitions[expected]?.contains(target) ?? false)) {
      throw const ApiError(
        409,
        'invalid_transition',
        'Esta mudança de status não é permitida.',
      );
    }
    final updated = await repository.transition(
      id: id,
      expected: expected,
      target: target,
      actorId: actor.id,
      expectedPricingId: quote.pricingId!,
    );
    if (updated == null) {
      throw const ApiError(
        409,
        'status_changed',
        'O status mudou. Atualize antes de continuar.',
      );
    }
    return await repository.find(id) ?? updated;
  }

  Future<QuoteRequest> create(Principal actor, Map<String, dynamic> data) =>
      repository.create(prepare(actor, data));

  QuoteRequest prepare(
    Principal actor,
    Map<String, dynamic> data, {
    String? id,
  }) {
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
    return QuoteRequest(
      id: id ?? const Uuid().v4(),
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
    );
  }
}
