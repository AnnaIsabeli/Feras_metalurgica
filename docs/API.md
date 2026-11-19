# API v1 implementada

Base local: `http://localhost:8080`. JSON UTF-8. Criação limitada a 16 KiB.

| Método | Caminho | Acesso | Resposta |
|---|---|---|---|
| GET | `/health` | Público | 200 processo disponível |
| GET | `/ready` | Público | 200 tabela acessível / 503 indisponível |
| GET | `/v1/me` | Autenticado | id, role, sellerApproved |
| GET | `/v1/quote-requests` | Comprador/vendedor aprovado | `{ "items": [...] }` |
| POST | `/v1/quote-requests` | Comprador | 201 solicitação criada |
| POST | `/v1/pricing/calculate` | Vendedor aprovado | 200 simulação de preço e DRE |

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

## Simulação de preço

```json
{
  "costs": [{"name": "Aço / kg", "quantity": 2, "unitCost": 50}],
  "rates": {
    "simplesNacionalRate": 0.045, "pisCofinsRate": 0, "irCsllRate": 0,
    "freightRate": 0.03, "commissionRate": 0.02, "substitutionTaxRate": 0,
    "fixedExpenseRate": 0.4, "targetNetMarginRate": 0.15
  },
  "practicedPrice": 300
}
```

Custos correspondem a uma unidade do produto. `practicedPrice` é opcional, em reais.
Os oito percentuais são obrigatórios, como frações entre 0 e 1. De 1 a 100 insumos,
nomes de até 120 caracteres, números finitos de magnitude até 1e12 e corpo até 16 KiB.
O motor também valida CMV positivo, preço praticado positivo e divisor positivo.
Retorna `cmv`, `divisor`, `markupMultiplier`, `suggested` e `practiced` (ou null).
Cada DRE contém `revenue`, `cmv`, `variableExpenses`, `contributionMargin`,
`contributionMarginRate`, `fixedExpenses`, `netProfit` e `netMarginRate`.
A simulação não persiste dados nem modifica o status da solicitação.

## Interface

Comprador: Início → Solicitar orçamento → confirmação → Orçamentos → detalhes.
Vendedor: Orçamentos → solicitação → Precificar esta solicitação, ou Início →
Simular preço de venda. Custos, percentuais e negociação são editáveis; o cálculo
é executado exclusivamente na API. Alterar entradas invalida o resultado anterior.
A aba Conta consulta `/v1/me` e permite tentar novamente em caso de erro.
São mantidos os três destinos, com Conta no lugar dos antigos espaços reservados
de Pedidos/Contato, que ainda não têm operações de backend.

`CORS_ORIGIN` aceita uma lista de origens completas separadas por vírgula,
por exemplo `http://localhost:5000,https://seu-dominio.example`. Não aceita curingas.
Para Cloudflare, configurar o endereço HTTPS efetivo; um Quick Tunnel pode mudar
de endereço quando reiniciado. A configuração do servidor e o volume antigo do
banco não foram alterados por esta implementação.

Login Google, anexos, persistência/envio/aceite de proposta e pedidos continuam
pendentes. Não há botão que simule sucesso nessas operações.
