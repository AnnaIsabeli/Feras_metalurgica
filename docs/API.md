# API v1 implementada

Base local: `http://localhost:8080`. JSON UTF-8. Criação limitada a 16 KiB.

| Método | Caminho | Acesso | Resposta |
|---|---|---|---|
| GET | `/health` | Público | 200 processo disponível |
| GET | `/ready` | Público | 200 tabela acessível / 503 indisponível |
| GET | `/v1/me` | Autenticado | id, role, sellerApproved |
| GET | `/v1/quote-requests` | Comprador/vendedor aprovado | `{ "items": [...] }` |
| POST | `/v1/quote-requests` | Comprador | 201 solicitação criada |

Use `Authorization: Bearer <token>`. Apenas em development explícito: `demo-buyer` e `demo-seller`.
Login Google ainda não integrado; acesso privado em produção é negado.

```json
{"product":"Portão de correr","description":"Abertura de 3 m, aço e madeira escura.","quantity":1}
```

Produto/descrição não vazios, até 120/4000 caracteres; quantidade inteira de 1 a 10000.
Dono e estado enviados pelo cliente são ignorados. Resposta inclui `id`, `buyerId`, campos acima,
`status: "received"` e `createdAt` UTC ISO 8601.

Listagem limitada a 100 registros, mais recentes primeiro. Paginação pendente.
Comprador recebe somente seus registros; vendedor aprovado vê solicitações.

Erros: `{"error":{"code":"invalid_request","message":"Informe produto..."}}`.
400 JSON inválido; 401 sem identidade; 403 papel/origem negados; 413 corpo grande;
415 formato não JSON; 422 campos inválidos; 500 erro interno sem detalhes do banco.

Anexos, preço, envio/aceite de proposta e pedidos não possuem endpoints implementados nesta base.
