# Validação — 16/09/2026

- Dependências da API resolvidas com Dart 3.13.3; lockfile incluído.
- Docker Desktop instalado, mas engine Linux não estava em execução.
- Flutter SDK preparado fora do repositório, em diretório de trabalho.
- Execução padrão do Flutter e runner de testes encontrou restrições de escrita/execução
  no Windows desta sessão. Testes escritos não equivalem a testes aprovados.
- Pipeline preparado para análise, API com PostgreSQL e testes/build Flutter.
  Ainda não executado no GitHub.

# Validação — KAN-11 e catálogo de materiais (implementação)

**Estado honesto: o código novo foi escrito e revisado, mas não foi compilado nem testado.**
O ambiente onde foi escrito não tinha Dart/Flutter nem acesso à rede. Nada aqui equivale a
teste aprovado. Antes de integrar, rodar os comandos de [EVIDENCIAS.md](EVIDENCIAS.md) e corrigir
o que o analisador ou os testes apontarem; é esperado que apareça algum ajuste pequeno.

Pontos que mais merecem atenção na primeira execução:

- `Sql.named` com `::text::numeric` e `ILIKE` (repositório de materiais) contra o PostgreSQL real.
- `ServerException.code == '23505'` para detectar material duplicado.
- Testes de widget com `MockClient` (`apps/mobile/test/permissions_ui_test.dart`).
- A migração 003 assume que a restrição original se chama `users_role_check` (nome padrão do PostgreSQL).
- Em volume do Docker já existente, `001`/`002` não rodam de novo: aplicar `002` e `003` manualmente
  (ver README).
