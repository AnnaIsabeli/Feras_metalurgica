import 'dart:convert';
import 'package:fera_api/src/auth/principal.dart';
import 'package:fera_api/src/core/config.dart';
import 'package:fera_api/src/http/app.dart';
import 'package:fera_api/src/materials/material_service.dart';
import 'package:fera_api/src/quotes/quote_service.dart';
import 'package:fera_contracts/fera_contracts.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'support/memory_repositories.dart';

const quoteId = '11111111-1111-4111-8111-111111111111';
const materialId = '22222222-2222-4222-8222-222222222222';

void main() {
  late MemoryQuotes quoteRepository;
  late MemoryMaterials materialRepository;
  late Handler handler;

  Handler build(IdentityVerifier identity) => buildHandler(
    quotes: QuoteService(quoteRepository),
    materials: MaterialService(materialRepository),
    identity: identity,
    checkDatabase: () async {},
    allowedOrigin: 'http://localhost:5000',
  );

  setUp(() {
    quoteRepository = MemoryQuotes()
      ..items.add(
        QuoteRequest(
          id: quoteId,
          buyerId: DevelopmentIdentityVerifier.buyerId,
          product: 'Portão',
          description: 'Portão de correr de 3 metros',
          quantity: 1,
          status: RequestStatus.received,
          createdAt: DateTime.utc(2026, 10, 1),
        ),
      );
    materialRepository = MemoryMaterials()
      ..items.add(
        CatalogMaterial(
          id: materialId,
          name: 'Metalon 40x30',
          unit: 'metro',
          unitCost: '13.333333',
          active: true,
          createdAt: DateTime.utc(2026, 10, 1),
          updatedAt: DateTime.utc(2026, 10, 1),
        ),
      );
    handler = build(DevelopmentIdentityVerifier());
  });

  Request request(
    String method,
    String path, {
    String? token,
    Object? body,
    String? origin,
  }) => Request(
    method,
    Uri.parse('http://localhost$path'),
    headers: {
      if (token != null) 'authorization': 'Bearer $token',
      'origin': ?origin,
      'content-type': 'application/json',
    },
    body: body == null ? null : jsonEncode(body),
  );

  Future<Map<String, dynamic>> json(Response r) async =>
      jsonDecode(await r.readAsString()) as Map<String, dynamic>;

  final validQuote = {
    'product': 'Portão',
    'description': 'Portão de correr de 3 metros',
    'quantity': 1,
  };
  final validMaterial = {'name': 'Eletrodo', 'unit': 'kg', 'unitCost': '25.5'};

  // ---------------------------------------------------------------------
  // Matriz perfil x rota. Cada linha vira um teste: (perfil, operação, status).
  // Tokens: sem login (null), Cliente, outro Cliente, Vendedor aprovado,
  // Vendedor não aprovado, Administrador.
  // ---------------------------------------------------------------------
  const none = null;
  const client = 'demo-buyer';
  const otherClient = 'demo-buyer-2';
  const seller = 'demo-seller';
  const pending = 'demo-seller-pending';
  const admin = 'demo-admin';
  final cases = <(String, String?, String, String, Object?, int)>[
    // (rótulo, token, método, caminho, corpo, status esperado)
    ('listar solicitações', none, 'GET', '/v1/quote-requests', null, 401),
    ('listar solicitações', client, 'GET', '/v1/quote-requests', null, 200),
    ('listar solicitações', seller, 'GET', '/v1/quote-requests', null, 200),
    ('listar solicitações', pending, 'GET', '/v1/quote-requests', null, 403),
    ('listar solicitações', admin, 'GET', '/v1/quote-requests', null, 200),
    ('ler solicitação', none, 'GET', '/v1/quote-requests/$quoteId', null, 401),
    ('ler solicitação', client, 'GET', '/v1/quote-requests/$quoteId', null, 200),
    ('ler solicitação de outro cliente', otherClient, 'GET', '/v1/quote-requests/$quoteId', null, 404),
    ('ler solicitação', seller, 'GET', '/v1/quote-requests/$quoteId', null, 200),
    ('ler solicitação', pending, 'GET', '/v1/quote-requests/$quoteId', null, 403),
    ('ler solicitação', admin, 'GET', '/v1/quote-requests/$quoteId', null, 200),
    ('PDF', none, 'GET', '/v1/quote-requests/$quoteId/pdf', null, 401),
    ('PDF do dono (autorizado; geração pendente)', client, 'GET', '/v1/quote-requests/$quoteId/pdf', null, 501),
    ('PDF de outro cliente', otherClient, 'GET', '/v1/quote-requests/$quoteId/pdf', null, 404),
    ('PDF', seller, 'GET', '/v1/quote-requests/$quoteId/pdf', null, 501),
    ('PDF', pending, 'GET', '/v1/quote-requests/$quoteId/pdf', null, 403),
    ('PDF', admin, 'GET', '/v1/quote-requests/$quoteId/pdf', null, 501),
    ('criar solicitação', none, 'POST', '/v1/quote-requests', validQuote, 401),
    ('criar solicitação', client, 'POST', '/v1/quote-requests', validQuote, 201),
    ('criar solicitação', seller, 'POST', '/v1/quote-requests', validQuote, 403),
    ('criar solicitação', pending, 'POST', '/v1/quote-requests', validQuote, 403),
    ('criar solicitação', admin, 'POST', '/v1/quote-requests', validQuote, 403),
    ('listar materiais', none, 'GET', '/v1/materials', null, 401),
    ('listar materiais', client, 'GET', '/v1/materials', null, 403),
    ('listar materiais', seller, 'GET', '/v1/materials', null, 200),
    ('listar materiais', pending, 'GET', '/v1/materials', null, 403),
    ('listar materiais', admin, 'GET', '/v1/materials', null, 200),
    ('materiais inativos', seller, 'GET', '/v1/materials?status=inactive', null, 403),
    ('materiais inativos', seller, 'GET', '/v1/materials?status=all', null, 403),
    ('materiais inativos', admin, 'GET', '/v1/materials?status=inactive', null, 200),
    ('cadastrar material', none, 'POST', '/v1/materials', validMaterial, 401),
    ('cadastrar material', client, 'POST', '/v1/materials', validMaterial, 403),
    ('cadastrar material', seller, 'POST', '/v1/materials', validMaterial, 403),
    ('cadastrar material', pending, 'POST', '/v1/materials', validMaterial, 403),
    ('cadastrar material', admin, 'POST', '/v1/materials', validMaterial, 201),
    ('editar material', none, 'PATCH', '/v1/materials/$materialId', {'unitCost': '1'}, 401),
    ('editar material', client, 'PATCH', '/v1/materials/$materialId', {'unitCost': '1'}, 403),
    ('editar material', seller, 'PATCH', '/v1/materials/$materialId', {'unitCost': '1'}, 403),
    ('editar material', pending, 'PATCH', '/v1/materials/$materialId', {'unitCost': '1'}, 403),
    ('editar material', admin, 'PATCH', '/v1/materials/$materialId', {'unitCost': '1'}, 200),
    ('desativar material', seller, 'PATCH', '/v1/materials/$materialId', {'active': false}, 403),
    ('desativar material', admin, 'PATCH', '/v1/materials/$materialId', {'active': false}, 200),
    ('perfil /me', none, 'GET', '/v1/me', null, 401),
    ('perfil /me', client, 'GET', '/v1/me', null, 200),
    ('perfil /me', pending, 'GET', '/v1/me', null, 200),
  ];
  for (final c in cases) {
    final (label, token, method, path, body, expected) = c;
    test('${token ?? 'sem login'} | $label | $method $path -> $expected', () async {
      final response = await handler(request(method, path, token: token, body: body));
      expect(response.statusCode, expected);
    });
  }

  group('negativos de segurança', () {
    test('acesso negado não altera dados', () async {
      for (final token in [none, client, seller, pending]) {
        await handler(request('POST', '/v1/materials', token: token, body: validMaterial));
        await handler(request('PATCH', '/v1/materials/$materialId', token: token, body: {'unitCost': '999', 'active': false}));
      }
      expect(materialRepository.items, hasLength(1));
      expect(materialRepository.items.single.unitCost, '13.333333');
      expect(materialRepository.items.single.active, isTrue);
    });

    test('cliente B não vê dados do cliente A, nem na listagem', () async {
      final list = await json(await handler(request('GET', '/v1/quote-requests', token: otherClient)));
      expect(list['items'], isEmpty);
      final own = await json(await handler(request('GET', '/v1/quote-requests', token: client)));
      expect((own['items'] as List), hasLength(1));
    });

    test('404 de recurso alheio é igual ao de recurso inexistente', () async {
      final foreign = await handler(request('GET', '/v1/quote-requests/$quoteId', token: otherClient));
      final missing = await handler(request('GET', '/v1/quote-requests/99999999-9999-4999-8999-999999999999', token: otherClient));
      expect(foreign.statusCode, missing.statusCode);
      expect(await foreign.readAsString(), await missing.readAsString());
    });

    test('id malformado é 404, não erro interno', () async {
      for (final path in ['/v1/quote-requests/abc', '/v1/materials/abc']) {
        expect((await handler(request('GET', path, token: admin))).statusCode, 404);
      }
      expect((await handler(request('PATCH', '/v1/materials/abc', token: admin, body: {'active': false}))).statusCode, 404);
    });

    test('tokens demonstrativos não funcionam com o verificador de produção', () async {
      final production = build(DenyAllIdentityVerifier());
      for (final token in [client, otherClient, seller, pending, admin]) {
        expect((await production(request('GET', '/v1/me', token: token))).statusCode, 401);
        expect((await production(request('GET', '/v1/materials', token: token))).statusCode, 401);
      }
    });

    test('token desconhecido e cabeçalho sem Bearer são 401', () async {
      expect((await handler(request('GET', '/v1/me', token: 'qualquer'))).statusCode, 401);
      final noBearer = Request('GET', Uri.parse('http://localhost/v1/me'), headers: {'authorization': 'Basic abc'});
      expect((await handler(noBearer)).statusCode, 401);
    });

    test('perfil é decidido pelo servidor: corpo forjado não vira dono nem status', () async {
      final result = await handler(request('POST', '/v1/quote-requests', token: client, body: {...validQuote, 'buyerId': 'forged', 'status': 'quoted'}));
      expect(result.statusCode, 201);
      final body = await json(result);
      expect(body['buyerId'], DevelopmentIdentityVerifier.buyerId);
      expect(body['status'], 'received');
    });

    test('/v1/me devolve as permissões do perfil', () async {
      final adminMe = await json(await handler(request('GET', '/v1/me', token: admin)));
      expect(adminMe['role'], 'admin');
      expect(adminMe['permissions'], contains('writeMaterials'));
      final clientMe = await json(await handler(request('GET', '/v1/me', token: client)));
      expect(clientMe['permissions'], contains('createQuote'));
      expect(clientMe['permissions'], isNot(contains('readMaterials')));
      final pendingMe = await json(await handler(request('GET', '/v1/me', token: pending)));
      expect(pendingMe['permissions'], isEmpty);
    });
  });

  group('solicitações (validação existente)', () {
    test('quantidades inválidas, textos em branco e muito longos são 422', () async {
      for (final data in [
        {...validQuote, 'quantity': 0},
        {...validQuote, 'quantity': 1.5},
        {...validQuote, 'quantity': 10001},
        {...validQuote, 'product': '  '},
        {...validQuote, 'description': 'a' * 4001},
      ]) {
        expect((await handler(request('POST', '/v1/quote-requests', token: client, body: data))).statusCode, 422);
      }
      expect(quoteRepository.items, hasLength(1));
    });

    test('JSON inválido, origem não permitida e corpo grande têm erro explícito', () async {
      final malformed = Request('POST', Uri.parse('http://localhost/v1/quote-requests'), headers: {'authorization': 'Bearer demo-buyer', 'content-type': 'application/json'}, body: '{');
      expect((await handler(malformed)).statusCode, 400);
      expect((await handler(request('GET', '/health', origin: 'https://untrusted.example'))).statusCode, 403);
      expect((await handler(request('POST', '/v1/quote-requests', token: client, body: {'x': 'a' * 17000}))).statusCode, 413);
    });
  });

  group('catálogo de materiais', () {
    test('admin cadastra e o material fica disponível ao vendedor', () async {
      final created = await handler(request('POST', '/v1/materials', token: admin, body: {'name': '  Tinta  ', 'unit': ' litro ', 'unitCost': '20'}));
      expect(created.statusCode, 201);
      final body = await json(created);
      expect(body['name'], 'Tinta');
      expect(body['unit'], 'litro');
      expect(body['unitCost'], '20');
      expect(body['active'], isTrue);
      final listed = await json(await handler(request('GET', '/v1/materials', token: seller)));
      expect((listed['items'] as List).map((m) => (m as Map)['name']), contains('Tinta'));
    });

    test('custo decimal preserva as casas e aceita número JSON simples', () async {
      final a = await json(await handler(request('POST', '/v1/materials', token: admin, body: {'name': 'A', 'unit': 'm', 'unitCost': '13.333333'})));
      expect(a['unitCost'], '13.333333');
      final b = await json(await handler(request('POST', '/v1/materials', token: admin, body: {'name': 'B', 'unit': 'm', 'unitCost': 25})));
      expect(b['unitCost'], '25');
    });

    test('dados inválidos são rejeitados com 422 e nada é gravado', () async {
      final invalid = <Map<String, Object?>>[
        {'unit': 'kg', 'unitCost': '1'},
        {'name': '   ', 'unit': 'kg', 'unitCost': '1'},
        {'name': 'a' * 121, 'unit': 'kg', 'unitCost': '1'},
        {'name': 'X', 'unit': '', 'unitCost': '1'},
        {'name': 'X', 'unit': 'u' * 31, 'unitCost': '1'},
        {'name': 'X', 'unit': 'kg'},
        {'name': 'X', 'unit': 'kg', 'unitCost': '-1'},
        {'name': 'X', 'unit': 'kg', 'unitCost': 'abc'},
        {'name': 'X', 'unit': 'kg', 'unitCost': '1e3'},
        {'name': 'X', 'unit': 'kg', 'unitCost': '1,5'},
        {'name': 'X', 'unit': 'kg', 'unitCost': '1.1234567'},
        {'name': 'X', 'unit': 'kg', 'unitCost': '123456789'},
        {'name': 'X', 'unit': 'kg', 'unitCost': null},
        {'name': 5, 'unit': 'kg', 'unitCost': '1'},
      ];
      for (final data in invalid) {
        final r = await handler(request('POST', '/v1/materials', token: admin, body: data));
        expect(r.statusCode, 422, reason: 'corpo: $data');
      }
      expect(materialRepository.items, hasLength(1));
    });

    test('material duplicado (nome + unidade, sem diferenciar caixa) é 409', () async {
      final r = await handler(request('POST', '/v1/materials', token: admin, body: {'name': 'METALON 40X30', 'unit': 'Metro', 'unitCost': '1'}));
      expect(r.statusCode, 409);
      expect(materialRepository.items, hasLength(1));
    });

    test('editar nome, unidade e custo persiste e é recuperado', () async {
      final r = await handler(request('PATCH', '/v1/materials/$materialId', token: admin, body: {'name': 'Metalon 50x30', 'unit': 'barra', 'unitCost': '14.5'}));
      expect(r.statusCode, 200);
      final again = await json(await handler(request('GET', '/v1/materials/$materialId', token: seller)));
      expect(again['name'], 'Metalon 50x30');
      expect(again['unit'], 'barra');
      expect(again['unitCost'], '14.5');
    });

    test('edição inválida: vazio, custo ruim, active não booleano, id inexistente', () async {
      for (final data in <Map<String, Object?>>[{}, {'unitCost': '-2'}, {'name': ''}, {'active': 'sim'}]) {
        expect((await handler(request('PATCH', '/v1/materials/$materialId', token: admin, body: data))).statusCode, 422, reason: '$data');
      }
      final missing = await handler(request('PATCH', '/v1/materials/99999999-9999-4999-8999-999999999999', token: admin, body: {'unitCost': '1'}));
      expect(missing.statusCode, 404);
      expect(materialRepository.items.single.unitCost, '13.333333');
    });

    test('desativar não apaga: some para o vendedor, continua para o admin', () async {
      await handler(request('PATCH', '/v1/materials/$materialId', token: admin, body: {'active': false}));
      final sellerList = await json(await handler(request('GET', '/v1/materials', token: seller)));
      expect(sellerList['items'], isEmpty);
      expect((await handler(request('GET', '/v1/materials/$materialId', token: seller))).statusCode, 404);
      final adminList = await json(await handler(request('GET', '/v1/materials', token: admin)));
      expect(adminList['items'], hasLength(1));
      final inactive = await json(await handler(request('GET', '/v1/materials?status=inactive', token: admin)));
      expect(inactive['items'], hasLength(1));
      // Reativar.
      await handler(request('PATCH', '/v1/materials/$materialId', token: admin, body: {'active': true}));
      final active = await json(await handler(request('GET', '/v1/materials?status=active', token: seller)));
      expect(active['items'], hasLength(1));
    });

    test('não existe exclusão de material', () async {
      final r = await handler(request('DELETE', '/v1/materials/$materialId', token: admin));
      expect(r.statusCode, isNot(anyOf(200, 204)));
      expect(materialRepository.items, hasLength(1));
    });

    test('busca por nome ou unidade e status inválido', () async {
      await handler(request('POST', '/v1/materials', token: admin, body: validMaterial));
      final byName = await json(await handler(request('GET', '/v1/materials?q=metalon', token: admin)));
      expect(byName['items'], hasLength(1));
      final byUnit = await json(await handler(request('GET', '/v1/materials?q=kg', token: admin)));
      expect(byUnit['items'], hasLength(1));
      expect((await handler(request('GET', '/v1/materials?status=xyz', token: admin))).statusCode, 422);
      expect((await handler(request('GET', '/v1/materials?q=${'a' * 121}', token: admin))).statusCode, 422);
    });
  });

  test('autenticação demonstrativa não pode ser habilitada em produção', () {
    expect(
      () => AppConfig.fromEnvironment({
        'DATABASE_URL': 'postgresql://localhost/fera',
        'APP_ENV': 'production',
        'DEV_AUTH_ENABLED': 'true',
      }),
      throwsStateError,
    );
  });

  test('indisponibilidade do banco dá 503 sem detalhes internos', () async {
    final app = buildHandler(
      quotes: QuoteService(quoteRepository),
      materials: MaterialService(materialRepository),
      identity: DenyAllIdentityVerifier(),
      checkDatabase: () async => throw StateError('private connection details'),
      allowedOrigin: 'http://localhost:5000',
    );
    final result = await app(request('GET', '/ready'));
    expect(result.statusCode, 503);
    expect(await result.readAsString(), isNot(contains('private')));
  });
}
