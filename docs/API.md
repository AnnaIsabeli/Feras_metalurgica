# API v1 implementada

Base local: `http://localhost:8080`. JSON UTF-8. Corpo limitado a 16 KiB.
Matriz completa de acesso em [PERMISSIONS.md](PERMISSIONS.md).

| Método | Caminho | Acesso | Resposta |
|---|---|---|---|
| GET | `/health` | Público | 200 processo disponível |
| GET | `/ready` | Público | 200 tabela acessível / 503 indisponível |
| GET | `/v1/me` | Autenticado | `id`, `role`, `sellerApproved`, `permissions[]` |
| GET | `/v1/quote-requests` | Cliente (só as suas), vendedor aprovado, administrador | `{ "items": [...] }` |
| GET | `/v1/quote-requests/{id}` | Dono, vendedor aprovado, administrador | solicitação; 404 se inexistente ou de outro cliente |
| GET | `/v1/quote-requests/{id}/pdf` | Mesmas regras da leitura | 501 se autorizado (geração pendente) |
| POST | `/v1/quote-requests` | Cliente | 201 solicitação criada |
| GET | `/v1/materials?q=&status=` | Vendedor aprovado (só `active`), administrador (`active`, `inactive`, `all`; padrão `all`) | `{ "items": [...] }` |
| GET | `/v1/materials/{id}` | Vendedor aprovado (só ativo), administrador | material |
| POST | `/v1/materials` | Administrador | 201 material |
| PATCH | `/v1/materials/{id}` | Administrador | 200 material atualizado |

Não há `DELETE`: material é desativado com `{'active': false}`. A tela administrativa pede confirmação antes da desativação e informa que o histórico será preservado. Materiais ativos são consultáveis pelo vendedor aprovado via `GET /v1/materials` para uso como fonte de composição; a composição/precificação de uma proposta ainda não possui fluxo de gravação nesta versão.

Use `Authorization: Bearer <token>`. Apenas em development explícito: `demo-buyer`, `demo-buyer-2`,
`demo-seller`, `demo-seller-pending` e `demo-admin`. Login Google ainda não integrado;
acesso privado em produção é negado.

```json
{"product":"Portão de correr","description":"Abertura de 3 m, aço e madeira escura.","quantity":1}
```

Produto/descrição não vazios, até 120/4000 caracteres; quantidade inteira de 1 a 10000.
Dono e estado enviados pelo cliente são ignorados.

## Materiais

```json
{"name":"Metalon 40x30","unit":"metro","unitCost":"13.333333"}
```

- `name`: obrigatório, até 120 caracteres (espaços nas pontas são removidos).
- `unit`: obrigatório, até 30 caracteres.
- `unitCost`: texto decimal com ponto, não negativo, até 8 dígitos inteiros e 6 decimais.
  Número JSON simples também é aceito; notação científica, vírgula e negativos são rejeitados.
- `PATCH` aceita `name`, `unit`, `unitCost` e `active` (ao menos um). Só os campos enviados mudam.
- Nome + unidade não se repetem (sem diferenciar maiúsculas): 409.
- A busca `q` procura em nome e unidade, sem diferenciar maiúsculas; até 120 caracteres.
- Resposta: `id`, `name`, `unit`, `unitCost` (texto), `active`, `createdAt`, `updatedAt`.
- Alterar ou desativar material não muda orçamentos já feitos: eles guardam snapshot de nome,
  unidade e custo (`quote_pricing_items`).

Listagens limitadas (100 solicitações, 500 materiais), mais recentes ou por nome. Paginação pendente.

Erros: `{"error":{"code":"invalid_request","message":"..."}}`.
400 JSON inválido; 401 sem identidade; 403 perfil/origem negados (`forbidden`, `seller_not_approved`,
`origin_denied`); 404 inexistente ou de outro cliente; 409 material duplicado; 413 corpo grande;
415 formato não JSON; 422 campos inválidos (`invalid_request`, `invalid_material`);
501 PDF ainda não gerado (a rota aplica autenticação, perfil e propriedade antes de responder);  500 erro interno sem detalhes do banco.

Anexos, preço, envio/aceite de proposta e pedidos não possuem endpoints implementados nesta base.
