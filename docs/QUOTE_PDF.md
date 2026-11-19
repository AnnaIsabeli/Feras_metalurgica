# PDF do orçamento — S6-03 / KAN-44

O backend gera o documento a partir de uma **precificação persistida**, sem
recalcular o orçamento. Uma consulta consistente lê a solicitação, o cliente, a
revisão e os snapshots dos itens. O catálogo atual não é consultado.

## Contrato para a interface

`GET /v1/quote-requests/:id/pdf`

- Exige Bearer token de vendedor aprovado; em demonstração, `demo-seller`.
- Retorna `application/pdf` com `Content-Disposition: inline` para visualizar.
- `?download=1` retorna `attachment` para baixar.
- `?pricingId=UUID` seleciona uma revisão específica da mesma solicitação.
- Sem `pricingId`, usa a última revisão salva.
- Os cabeçalhos incluem `private, no-store` e `nosniff`.
- CORS expõe `Content-Disposition` para a interface obter o nome do arquivo.

A interface deve buscar os bytes com Authorization e depois abrir/baixar o PDF.
Não coloque o token em URLs. Na web, use Blob/application/pdf após o fetch
autenticado; no aplicativo, use o mecanismo de visualização/compartilhamento
adotado pelo grupo. A tela integrada da S3-06 disponibiliza Visualizar / imprimir PDF e Baixar /
compartilhar PDF. Os botões usam a revisão salva e ficam bloqueados enquanto
houver alterações ainda não salvas. O prazo opcional pode ser preenchido na tela.
A ação de visualização usa o diálogo nativo de impressão; a de download usa o
download do navegador ou o compartilhamento do sistema, sem recalcular o PDF.

Exemplo pelo terminal (ambiente demonstrativo):

```sh
curl --fail \
  -H 'Authorization: Bearer demo-seller' \
  'https://dev.orcex.shop/api/v1/quote-requests/UUID-DA-SOLICITACAO/pdf?download=1' \
  -o orcamento.pdf
```

## Conteúdo

Cliente e e-mail, solicitação, descrição, quantidade solicitada, nomes/unidades/
quantidades dos itens e valor total em reais. O preço por unidade vem de `quote_pricings.total_price_cents` (nome legado da
coluna), que representa o preço praticado ou sugerido para uma unidade do
produto, conforme a tela de precificação. O valor total do documento é esse
valor unitário em centavos multiplicado pela quantidade de produtos solicitada.
Para mais de uma unidade, o PDF distingue os itens por unidade, o preço unitário
e o total do pedido. Essa multiplicação não refaz impostos, despesas ou margens. Não aparecem custos unitários, taxas, CMV, markup,
margens ou resultado financeiro. A geração não altera status nem envia proposta.

O PDF identifica a revisão da precificação. Itens e preços são os snapshots da
revisão; identificação do cliente e descrição vêm dos registros atuais da
solicitação/cliente. Isto ainda não implementa assinatura, envio nem publicação
irrevogável de uma proposta comercial.

## Prazo variável

O POST de precificação aceita o campo opcional `deliveryLeadTime` no corpo:

```json
{"deliveryLeadTime": "20 dias úteis após a aprovação"}
```

Envie junto da composição completa já exigida pelo endpoint. Texto não vazio,
até 240 caracteres, sem quebras de linha. O valor é preservado no snapshot de
cada revisão e aparece somente quando preenchido. Para retirar o prazo, salve
uma nova revisão omitindo o campo ou com null. Não há validade nem condições de
pagamento no documento, conforme a definição atual do grupo.

## Acesso e erros

401: sem autenticação. 403: comprador ou vendedor não aprovado. 404: solicitação
sem precificação salva, ou revisão inexistente/não vinculada à solicitação.
409: registro legado sem itens. 422: UUID, opção de download ou caractere não
suportado pelas fontes. A política atual mantém o PDF restrito ao vendedor;
publicação para clientes depende do fluxo de autorização e aprovação do grupo.

Não exige nova migration. Fontes DejaVu são embarcadas, com licença em
`services/api/assets/fonts`; geração funciona sem baixar fontes e sem programas
externos no servidor. Datas de revisão usam UTC-3 (horário adotado pelo projeto).

## Verificação

`dart analyze --fatal-infos` e `dart test` em services/api. Os testes com banco
exigem TEST_DATABASE_URL de um banco de testes com migrations e seed aplicados.
PDF_TEST_OUTPUT_DIRECTORY permite guardar o exemplo persistido. Os exemplos do
tool/render_quote_pdf_example.dart cobrem uma página, 100 itens e ausência de
prazo. scripts/verify_quote_pdf.py usa pypdf 6.21.4 para verificar os textos,
valores, paginação e ausência de dados financeiros internos; o CI executa tudo.
A revisão visual é feita renderizando os PDFs com Poppler.
