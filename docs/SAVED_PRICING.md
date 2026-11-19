# Precificações persistentes — S3-03 e S3-04

Depende da migration 002 da Anna. A migration 003 acrescenta o snapshot completo
(entrada, taxas, preço praticado e resultado calculado pelo motor da Sprint 2).
Aplicar pelo runner habitual, com backup no deploy. Não alterar migrations aplicadas.

Todas as rotas abaixo exigem vendedor aprovado e Bearer token. No ambiente de
**demonstração**, o token é `demo-seller`; autenticação Google continua pendente.

- `GET /v1/materials`: materiais ativos, com `id`, `name`, `unit`, `unitCost`.
- `POST /v1/quote-requests/:id/pricing`: calcula no servidor e salva uma revisão
  completa vinculada à solicitação. Retorna 201.
- `GET /v1/quote-requests/:id/pricing`: recupera a última revisão salva.

Exemplo de corpo do POST:

```json
{
  "costs": [{"name": "Aço", "unit": "kg", "quantity": 2, "unitCost": 50}],
  "rates": {
    "simplesNacionalRate": 0.045,
    "pisCofinsRate": 0,
    "irCsllRate": 0,
    "freightRate": 0.03,
    "commissionRate": 0.02,
    "substitutionTaxRate": 0,
    "fixedExpenseRate": 0.4,
    "targetNetMarginRate": 0.15
  },
  "practicedPrice": 300
}
```

Cada item manual exige nome, unidade, quantidade positiva com até 3 casas e custo
não negativo com até 6 casas. Para material cadastrado, envie `materialId` e
`quantity`: nome, unidade e custo são obtidos no catálogo pelo servidor.
Materiais inexistentes/inativos são rejeitados. As taxas são frações (15% = 0.15).

A resposta contém `id`, `quoteRequestId`, `createdBy`, `createdAt`,
`totalPriceCents`, `input` e `result`. O total é o preço praticado, quando
informado, ou o sugerido; arredondado para centavos ao salvar. Custos unitários
mantêm precisão fracionária e itens guardam seus snapshots nas tabelas da Anna.

Para editar, reenvie a composição completa ao POST da mesma solicitação: uma nova
revisão é criada e passa a ser a recuperada pelo GET. Revisões anteriores são
preservadas no banco. Alterar/desativar materiais não recalcula orçamentos salvos.
Uma falha em qualquer item desfaz também o cabeçalho da revisão. Salvar uma
precificação não envia proposta ao cliente nem altera o status da solicitação.

Erros: 401 sem autenticação; 403 comprador/vendedor não aprovado; 404 solicitação
inexistente no POST ou nenhuma precificação no GET; 422 dados inválidos; 400 JSON
inválido; 413 corpo acima de 16 KiB; 415 tipo diferente de application/json.

Registros legados sem snapshot retornam `input` e `result` nulos, mantendo seu
total e autoria. A interface deve tratar essa situação sem inventar um cálculo.

A integração da tela Flutter é a S3-06. Esta entrega disponibiliza a persistência
e a API para essa integração.

## Verificação

Em `services/api`, execute `dart pub get`, `dart analyze --fatal-infos` e
`dart test`. Para incluir os testes reais de persistência, defina
`TEST_DATABASE_URL` apontando para um banco **de testes**, com migrations e seed
de desenvolvimento aplicados. Os testes cobrem reabertura por outra conexão,
precisão, snapshots após alteração do catálogo, revisões e rollback integral.
