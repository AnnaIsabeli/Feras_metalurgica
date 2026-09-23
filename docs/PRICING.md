# Motor de precificação — S2-01 e S2-02

Fonte: [Precificador_SemRateio_Fera_Metalúrgica.xlsx](https://docs.google.com/spreadsheets/d/1QurSq4K30fTYxFvBojDME49EIcLQyUkP/edit), exportada em 23/09/2026. As referências abaixo são células dessa versão. Os valores são exemplos da empresa, não regras tributárias universais.

## Entradas e unidades

Cada `PricingCost` identifica um insumo, sua quantidade consumida e seu custo unitário em reais. Quantidade e custo devem usar a mesma unidade (metro, litro, kg ou unidade). Na origem, `Custos dos Insumos!J8:J115 = I/H`: valor da compra dividido pela quantidade comprada. A ficha técnica usa `quantidade consumida × custo unitário` (coluna E), buscando a primeira correspondência exata do nome com XLOOKUP. Há nomes repetidos no cadastro; o cálculo recebe custos já resolvidos, sem consultar catálogo ou banco.

Os oito percentuais são obrigatórios e nomeados: Simples Nacional, PIS/COFINS, IR/CSLL, frete, comissão, ST, despesas fixas e margem líquida desejada. São frações: **4,5% = 0.045**, nunca 4.5. O preço praticado é opcional. Custos e receitas devem corresponder à mesma ficha/produto; quantidade de produtos do pedido não é a quantidade de insumo e deve ser tratada na integração futura.

## Fórmulas

Para uma ficha técnica e um cenário:

```text
custo unitário = valor da compra / quantidade comprada
custo do insumo = quantidade consumida × custo unitário
CMV = soma dos custos dos insumos
taxa variável = Simples + PIS/COFINS + IR/CSLL + frete + comissão + ST
divisor = 1 − (taxa variável + taxa fixa + margem líquida desejada)
preço sugerido = CMV / divisor
markup multiplicador = 1 / divisor

receita = preço sugerido (ou preço praticado na segunda DRE)
despesas variáveis = receita × taxa variável
margem de contribuição = receita − CMV − despesas variáveis
despesas fixas = receita × taxa fixa
lucro líquido = margem de contribuição − despesas fixas
margem bruta = 1 − CMV / receita
margem de contribuição percentual = margem de contribuição / receita
margem líquida efetiva = lucro líquido / receita
```

Rastreabilidade: fichas `Portão Aço 3M` e `Prateleira_2`, E8:E24 e total E30; abas `Preco_Portão` e `Preco_Prateleira_2`, C7 (CMV), D:G nas linhas 9:15 (taxas), 19 (margem desejada), 7 (preço), 27:34 (DRE sugerida), 37:44 (DRE praticada). Não há custo de mão de obra separado no CMV da fonte. Não se acrescenta mão de obra ou perda presumida automaticamente.

## Percentuais da fonte

| Cenário | Simples | Frete | Comissão | Despesa fixa | Margem Portão | Margem Prateleira |
|---|---:|---:|---:|---:|---:|---:|
| Orçamento Simples (D) | 4,5% | 3% | 2% | 40% | 15% | 20% |
| MEI (E) | 0% | 3% | 2% | 34,166666…% | 20% | 20% |
| SP (F) | 4% | 0% | 3% | 10% | 20% | 20% |
| RS (G) | 4% | 0% | 3% | 15% | 15% | 15% |

PIS/COFINS, IR/CSLL e ST são zero nos oito exemplos, mas continuam parâmetros independentes do motor. A taxa fixa MEI vem de E15: `(1000 + 800 + 150 + 300 + 8000) / 30000`, total de 10.250 dividido por 30.000. A fonte não identifica os nomes desses cinco custos nem a descrição do denominador; não atribuímos categorias sem confirmação. Esses valores estão documentados e nos exemplos de teste, nunca embutidos no calculador.

## Casos de referência

| Produto | CMV sem arredondamento | Preço Simples | MEI | SP | RS |
|---|---:|---:|---:|---:|---:|
| Portão | 1.053,433333… | 2.967,42 | 2.579,84 | 1.672,12 | 1.672,12 |
| Prateleira | 783,733333… | 2.569,62 | 1.919,35 | 1.244,02 | 1.244,02 |

Na coluna Simples, o Portão tem despesas variáveis de R$281,9046948, contribuição de R$1.632,079812 e lucro de R$445,1126761. A Prateleira tem despesas variáveis de R$244,1136612, contribuição de R$1.541,770492 e lucro de R$513,9234973. Os preços praticados são, respectivamente, R$3.000 e R$1.900; os lucros efetivos são R$461,5666667 e R$175,7666667. Uma negociação pode gerar prejuízo; o resultado negativo não é ocultado.

Todas as quantidades, compras e referências por célula estão em `services/api/test/fixtures/pricing_workbook.json`. A expectativa dos testes foi extraída dos resultados armazenados pela planilha, não calculada pelo próprio motor. O teste reconstrói custos unitários a partir das compras e compara as duas DREs dos oito cenários.

## Precisão e validação

A fonte não usa ROUND/ARRED nas fórmulas auditadas: quatro casas são exibidas nas linhas de insumos, duas nos totais e preços. O motor mantém `double` sem arredondamentos intermediários para reproduzir esse comportamento. Na apresentação, formatar moeda com duas casas e percentuais multiplicados por 100. A tolerância dos testes contra o arquivo é R$0,00001, pois o cache exportado contém aproximadamente dez algarismos significativos. Esta etapa é de simulação; uma futura persistência financeira deverá definir explicitamente a quantização em centavos e recalcular a DRE pelo preço efetivamente cobrado.

O motor lança `ArgumentError` para percentuais fora de [0,1], valores não finitos, quantidades/custos negativos, lista vazia, nomes vazios, CMV total zero, preço praticado não positivo e divisor menor ou igual a zero. Zero por item é permitido se o CMV total for positivo. O preço sugerido também deve ser finito e positivo. Margem desejada zero é válida; preço praticado pode ficar abaixo do custo. Nenhuma validação depende de HTTP, Flutter ou PostgreSQL.

## Inconsistências da planilha e decisões

- D21 contém o número fixo 2,86, divergente do markup real nos dois produtos. O motor calcula `1/divisor`.
- G21 divide G7/F7; E23:G23 comparam preços de cenários diferentes. Não representam o multiplicador/divisor do respectivo cenário. O motor usa a fórmula de formação do preço da linha 7, consistente com a DRE.
- F7/G7 ficam vazios quando a margem desejada não é positiva. Essa condição é de exibição da planilha; o motor permite margem zero desde que o divisor seja positivo.
- A ficha Prateleira conserva o título de Portão e informa 20 kg de eletrodo. Esse consumo foi preservado para rastreabilidade, mas precisa de validação comercial antes de virar um orçamento real.
- XLOOKUP da fonte retorna zero quando não acha um insumo. A futura camada de catálogo deve rejeitar insumos não encontrados; o motor recebe valores explícitos e não procura nomes.
- O total E30 soma somente E8:E24; linhas E25:E29 estão vazias nos exemplos. O motor soma todos os itens recebidos, sem limite artificial de linhas.

## Uso e verificação

Implementação: `services/api/lib/src/pricing/`. `PricingCalculator().calculate(input)` devolve CMV, divisor, preço sugerido, markup e as DREs `suggested` e, se informado, `practiced`. Todos os parâmetros comerciais vêm de `PricingInput`; não há tabela fiscal embutida nem dependências novas.

```sh
cd services/api
dart pub get
dart analyze --fatal-infos
dart test test/pricing_calculator_test.dart
```

S2-01 entrega o mapeamento acima; S2-02 entrega o cálculo puro e testes. Expor uma rota de orçamento, gravar preços e conectar as telas Flutter são etapas posteriores; este módulo ainda não altera o fluxo publicado.

### Validação local em 23/09/2026

Análise pelo pacote analyzer: zero diagnósticos. Verificação direta em Dart: 168 checagens aprovadas, cobrindo os oito cenários, as duas DREs e rejeição de entradas inválidas. Reprodução, a partir de `services/api`: `dart tool/verify_pricing.dart`. O verificador lança erro e encerra com falha caso algum valor divirja; não usa asserts que possam estar desativados.

O executor padrão `dart test` foi impedido pelo ambiente Windows (`SignalException: Failed to listen for SIGINT`, acesso negado). Portanto, a suíte completa `pricing_calculator_test.dart` está escrita e analisada, mas não foi executada localmente pelo runner. O CI existente executará essa suíte junto aos demais testes quando a branch for enviada. A tentativa de validação via SSH não alcançou o servidor; nenhum deploy foi realizado.
