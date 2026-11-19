# Implementação e situação de aceite — KAN-11 / KAN-32

Atualização desta cópia do projeto: 18/11/2026.

## KAN-11 — perfis e permissões

### Já implementado no código entregue

- Papéis técnicos `buyer`, `seller` e `admin` (interface apresenta Cliente, Vendedor e Administrador).
- Política centralizada em `services/api/lib/src/auth/policy.dart`, com negação por padrão.
- Cliente cria solicitações e só lista/lê/PDF das próprias solicitações; acesso a recurso alheio retorna 404.
- Vendedor não aprovado recebe 403; vendedor aprovado consulta solicitações e materiais ativos.
- Administrador consulta solicitações e gerencia materiais, inclusive inativos.
- A interface obtém papel e permissões de `GET /v1/me`; esconder controles não substitui a autorização na API.
- Tokens `demo-*` só são aceitos com `APP_ENV=development` e `DEV_AUTH_ENABLED=true`. A configuração impede ativá-los em produção.
- Fora da demonstração, o verificador padrão é `DenyAllIdentityVerifier`: falha fechada, sem aceitar tokens demonstrativos.
- A rota de PDF autentica e aplica perfil/propriedade antes de responder; geração do arquivo permanece pendente (501 após autorização).

### Pendências para aceite integral

1. Integrar login Google no Flutter e verificação real do token no servidor. Requer OAuth Client ID(s) e decisão do grupo sobre associação/cadastro de contas e aprovação de vendedores.
2. Implementar geração do PDF quando existir o conteúdo final de proposta; hoje existe somente a barreira de autorização.
3. Obter aprovação explícita da matriz pelo grupo e registrar responsável/data em `docs/PERMISSIONS.md`.
4. Executar testes e anexar resultados reais. Testes escritos não são evidência de aprovação.

## KAN-32 — catálogo de materiais

### Já implementado no código entregue

- PostgreSQL: `materials`, custo `NUMERIC(14,6)`, validações e unicidade case-insensitive de nome + unidade.
- API: listar/pesquisar por nome ou unidade, consultar material, cadastrar, editar e desativar via `PATCH active=false`.
- API autoriza escrita somente para administrador; vendedor aprovado consulta apenas ativos; cliente e vendedor não aprovado são negados.
- Interface: administrador tem busca, filtros Todos/Ativos/Inativos, formulário de cadastro/edição e ativação/desativação. Vendedor aprovado vê somente materiais ativos e não vê controles de escrita.
- A desativação agora pede confirmação e informa que o registro/histórico serão preservados; a interface só confirma sucesso quando a API retorna sucesso.
- Não existe operação DELETE. O vínculo de item histórico usa `ON DELETE SET NULL`, e os snapshots preservam nome, unidade e custo.
- Migração e testes PostgreSQL cobrem a preservação de snapshots ao editar/desativar materiais.

### Pendências para aceite integral

1. A composição/precificação efetiva de uma proposta ainda não tem fluxo de gravação/API/UI. O catálogo ativo já é consultável pelo vendedor, mas isso não equivale a uma tela de composição completa.
2. Os três itens do seed (`Metalon 40x30`, `Eletrodo`, `Tinta`) vêm dos dados de demonstração S3-02/KAN-32 e estão explicitamente marcados como não conferidos pela empresa. Não devem ser tratados como catálogo real.
3. O grupo/empresa precisa fornecer a relação real conferida de materiais, unidades e custos; não é seguro inventar ou presumir esses dados.
4. Executar testes com PostgreSQL real e Flutter e anexar capturas/saídas.

## Verificações locais

Nesta sessão não há executáveis `dart`, `flutter` ou `docker` disponíveis. Por isso, nenhuma análise, suíte automatizada, build Flutter ou integração PostgreSQL foi declarada como aprovada. Execute os comandos de `docs/EVIDENCIAS.md` em ambiente com SDKs e Docker instalados.

## Decisões que não foram presumidas

- Não habilitar autenticação demonstrativa em produção.
- Não substituir a autenticação final por um token estático ou por identidade enviada pelo cliente.
- Não gerar um PDF fictício sem uma proposta final persistida.
- Não inventar materiais, custos ou conferência empresarial.
- Não marcar a matriz como aprovada sem decisão do grupo.
