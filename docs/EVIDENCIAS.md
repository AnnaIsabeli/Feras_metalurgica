# Evidências de aceite

A matriz de testes automatizados e os roteiros manuais estão preparados. **Não há resultados de execução anexados nesta entrega**; portanto, os critérios abaixo continuam sem aceite até rodar os comandos e guardar as saídas reais.

Comandos:

```
# API (precisa de PostgreSQL com migrações 001, 002, 003 e seeds/development.sql)
cd services/api && dart pub get && dart analyze --fatal-infos
TEST_DATABASE_URL=postgresql://... dart test
# Flutter
cd apps/mobile && flutter pub get && flutter analyze && flutter test
```

## KAN-11: perfis e permissões

| Critério | Teste | Resultado |
|---|---|---|
| Matriz por perfil, positivo e negativo (Cliente, Vendedor aprovado, não aprovado, Administrador) | `services/api/test/policy_test.dart` (um teste por perfil × permissão) e `app_test.dart` (matriz HTTP, uma linha por perfil × rota) | |
| Acesso sem login | `app_test.dart`: todas as rotas protegidas com `sem login -> 401`; cabeçalho sem Bearer e token desconhecido | |
| Dado de outro cliente (solicitação e PDF) | `app_test.dart`: "cliente B não vê dados do cliente A", "404 de recurso alheio é igual ao inexistente"; `postgres_test.dart`: isolamento no PostgreSQL | |
| Token demo não vale fora de development | `app_test.dart`: "tokens demonstrativos não funcionam com o verificador de produção"; "autenticação demonstrativa não pode ser habilitada em produção" | |
| A interface representa as permissões | `apps/mobile/test/permissions_ui_test.dart` | |
| Decisões documentadas | `docs/DECISIONS.md`, `docs/PERMISSIONS.md` | |
| Matriz validada com o grupo | `docs/PERMISSIONS.md` (assinatura/data) | PENDENTE — decisão coletiva e responsável a definir |

## Catálogo de materiais

| Critério | Teste | Resultado |
|---|---|---|
| Listar e pesquisar | `app_test.dart` "busca por nome ou unidade"; `postgres_test.dart` "busca trata % e _ como texto" | |
| Cadastrar e editar nome, unidade, custo; persistem e são recuperados | `app_test.dart` "editar ... persiste"; `postgres_test.dart` "cadastra, edita, desativa e recupera" | |
| Dados inválidos rejeitados | `app_test.dart` "dados inválidos são rejeitados com 422"; `postgres_test.dart` restrições do banco | |
| Acesso indevido negado | `app_test.dart`: cadastrar/editar/desativar com cada perfil; "acesso negado não altera dados" | |
| Desativar sem apagar; ativos disponíveis ao vendedor | `app_test.dart` "desativar não apaga..."; "não existe exclusão" | |
| Alterar/desativar não muda custos de orçamentos antigos | `postgres_test.dart` "editar ou desativar material NÃO altera o custo de orçamentos antigos" | |
| Operações pela interface | `apps/mobile/test/material_view_model_test.dart`, `permissions_ui_test.dart` | |
| Reabrir e recuperar pela interface | **Manual** (roteiro abaixo) | PENDENTE — executar e anexar capturas |
| Materiais reais conferidos cadastrados | **Pendente** (abaixo) | PENDENTE — dados de origem ainda não conferidos pela empresa |

### Roteiro manual (persistência pela interface)

1. `./scripts/demo.ps1` e `flutter run -d chrome --web-port 5000 --dart-define=ENABLE_DEMO=true`.
2. Entrar como **administrador** → Catálogo → cadastrar "Teste manual", unidade "metro", custo "12,5".
3. Editar o custo para "13,75"; desativar com o interruptor.
4. Sair, fechar o navegador, reabrir e entrar de novo como administrador: o material aparece com 13,75 e inativo (filtro Inativos).
5. Entrar como **vendedor**: aba Materiais não lista o material inativo e não mostra botões de edição.
6. Entrar como **cliente**: não há aba de materiais.
7. Anexar capturas de tela aqui.

### Materiais reais da empresa

`database/seeds/catalogo_demonstracao.sql` tem só os 3 itens do gerador (Metalon 40x30, Eletrodo,
Tinta), **valores de demonstração não conferidos**. O catálogo real deve ser cadastrado pelo
administrador na tela de Catálogo depois de conferido com a empresa. Lista a conferir:

| Material | Unidade | Quantidade comprada | Valor da compra | Custo unitário | Conferido por / data |
|---|---|---|---|---|---|
| | | | | | |
