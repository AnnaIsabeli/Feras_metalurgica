# Roadmap de desenvolvimento

Ordem sugerida; combinar responsáveis e datas com o grupo. Não são horas trabalhadas nem
compromissos automaticamente assumidos. Cada etapa precisa de demonstração e teste.

| Etapa | Entrega | Critério de conclusão |
|---|---|---|
| 1 — Base / Sprint 2 | Flutter, API Dart, PostgreSQL e primeira solicitação | Criar como comprador, consultar como vendedor e manter dados após reinício |
| 2 — Identidade | Google, sessão e aprovação de vendedor | Conta não aprovada bloqueada; dados de outro comprador inacessíveis; sair encerra sessão |
| 3 — Solicitações | Detalhes, anexos e complemento | Recebida → aguardando informações → elaboração com histórico |
| 4 — Precificação | Insumos, ficha técnica e motor da planilha | Resultados conferem com Excel, incluindo frações, arredondamento e divisor inválido |
| 5 — Propostas | Rascunho, condições, versões e envio | Cliente recebe só dados comerciais; alteração após envio cria nova versão |
| 6 — Pedidos | Aceite, recusa, ajuste, fabricação e entrega | Aceite cria um único pedido; transições inválidas e duplo aceite bloqueados |
| 7 — Homologação | Testes completos, acessibilidade, backup e implantação | Fluxo ponta a ponta e restauração testados; segredos fora do app |

## Sprint 2

- [x] Definir arquitetura e responsabilidades.
- [x] Criar estrutura Flutter/Dart e contratos.
- [x] Implementar criação/listagem com regras de acesso.
- [x] Escrever migração PostgreSQL e configuração Docker.
- [x] Preparar testes e integração contínua.
- [ ] Executar demonstração completa com PostgreSQL/Flutter no ambiente do grupo.
- [ ] Conferir nomes/estados com o protótipo final.
- [ ] Revisar e integrar código no GitHub com a colega.
- [ ] Preencher Controle Sprint v3 com responsáveis e horas reais.

## Antes da precificação

Confirmar planilha oficial, compra/consumo, desperdício, mão de obra, rateio ou ausência dele,
frete, tributos, comissão, margem e desconto. Escolher casos aprovados pela empresa/professora.
Não transformar percentuais demonstrativos do Figma em regras fixas para todas as vendas.

## Divisão sugerida

Frentes: telas/navegação; API/banco; regras/testes/documentação. Distribuir conforme a disponibilidade
e revisar em conjunto. Registrar somente atividades efetivamente feitas e suas horas reais.
