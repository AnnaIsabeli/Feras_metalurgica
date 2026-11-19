# Catálogo conferido da planilha

Fonte: `Precificador_SemRateio_Fera_Metalúrgica.xlsx`, aba `Custos dos Insumos`, linhas 8–26, conforme extração preservada em 26/10/2026. Valores são os registrados na planilha, não uma cotação atual.

`database/catalogo/materiais_planilha.json` preserva 19 compras e 18 combinações distintas de nome/unidade. As duas compras de Metalon 20x20 têm o mesmo custo; a mais recente é selecionada. Nomes diferentes de tábuas permanecem distintos. O custo é valor de compra dividido pela quantidade comprada, arredondado a seis casas; a razão original também é preservada.

`python3 scripts/catalogo_planilha.py` valida sem alterar banco. `--sql` emite importação transacional aditiva; registros conflitantes não são sobrescritos. Revisar conflitos antes de aplicar ao servidor. Orçamentos antigos continuam usando seus snapshots.

As três linhas do catálogo anterior eram exemplos e não representam a lista completa. A edição operacional pela interface permanece no escopo KAN-42, assim como validação de unidades e importação no ambiente correto.
