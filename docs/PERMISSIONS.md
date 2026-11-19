# Perfis e permissões (KAN-11)

Fonte única da regra no código: `services/api/lib/src/auth/policy.dart`
(função `isAllowed`). O teste `services/api/test/policy_test.dart` escreve esta
matriz como dados; se a política mudar, o teste falha até a matriz e este
documento serem atualizados. A interface lê as permissões em `GET /v1/me`
e só **representa** a matriz; a API é quem nega a operação.

Perfis: **Cliente** (identificador técnico `buyer`), **Vendedor** (`seller`, precisa de
`seller_approved = true`) e **Administrador** (`admin`).

| Operação | Sem login | Cliente | Vendedor aprovado | Vendedor não aprovado | Administrador |
|---|---|---|---|---|---|
| Ver o próprio acesso (`GET /v1/me`) | 401 | sim | sim | sim (sem permissões) | sim |
| Criar solicitação (`POST /v1/quote-requests`) | 401 | sim | sim (com dados do cliente) | 403 | 403 |
| Listar solicitações | 401 | só as suas | todas | 403 | todas |
| Ler uma solicitação (`GET /v1/quote-requests/{id}`) | 401 | só a sua (outra: 404) | sim | 403 | sim |
| PDF da solicitação (`.../pdf`) | 401 | só o seu (outro: 404) | sim | 403 | sim |
| Consultar materiais ativos (`GET /v1/materials`) | 401 | 403 | sim | 403 | sim |
| Consultar materiais inativos (`?status=inactive\|all`) | 401 | 403 | 403 | 403 | sim |
| Cadastrar / editar / desativar material | 401 | 403 | 403 | 403 | sim |
| Excluir material | não existe | não existe | não existe | não existe | não existe |

Códigos de erro: `401 unauthorized`, `403 forbidden`, `403 seller_not_approved`,
`404 not_found`, `409 duplicate_material`, `422 invalid_*`.

## Pontos para o grupo validar

Estas são as decisões que assumi como proposta. Confirmar ou corrigir; a mudança é
uma linha em `isAllowed` mais a linha correspondente em `policy_test.dart`.

1. O vendedor aprovado vê **todas** as solicitações (como já era), e não só as atribuídas a ele.
2. O vendedor aprovado pode registrar solicitações recebidas por canais externos, informando o cliente; o administrador não cria solicitações.
3. Solicitação de outro cliente responde **404** (igual a "não existe"), não 403.
4. Vendedor aprovado só vê materiais **ativos**; inativos são do administrador.

Validação da matriz pelo grupo: **PENDENTE** — preencher após decisão coletiva.

Responsável pela validação: a definir pelo grupo.  Data: ___/___/______

## Autenticação: demonstração x final

| | Demonstração local | Final (pendente) |
|---|---|---|
| Quando vale | `APP_ENV=development` e `DEV_AUTH_ENABLED=true` (a API recusa subir com isso fora de development) | Produção |
| Credencial | Tokens fixos `demo-buyer`, `demo-buyer-2`, `demo-seller`, `demo-seller-pending`, `demo-admin` | ID token Google verificado no servidor |
| Quem define o papel | Tabela fixa no código (`DevelopmentIdentityVerifier`) | Linha do usuário no banco (`users.role`, `seller_approved`); nunca o token nem o Flutter |
| Sem a configuração | `DenyAllIdentityVerifier`: **todo** acesso privado é negado, inclusive tokens `demo-*` | n/a |
| Interface | Botões só com `--dart-define=ENABLE_DEMO=true` | Login Google |

A autenticação final já possui verificador Google no servidor (`GoogleIdentityVerifier`) e resolução de conta pelo banco. A ativação depende de configurar `GOOGLE_CLIENT_IDS`, manter `DEV_AUTH_ENABLED=false` fora do desenvolvimento e validar um login real no ambiente publicado. A API nega por padrão quando não há identidade válida. O papel e a aprovação vêm do banco, nunca do token ou do Flutter.

**Pendências externas:** o grupo precisa validar a matriz de permissões e definir quais contas recebem o papel de administrador. O procedimento de deploy e os limites da integração Google estão em `docs/GOOGLE_AUTH.md`.
