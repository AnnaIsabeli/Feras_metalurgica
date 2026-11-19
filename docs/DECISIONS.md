# Decisões (KAN-11 e catálogo de materiais)

| # | Decisão | Motivo |
|---|---|---|
| 1 | Perfil "Cliente" mantém o identificador técnico `buyer` (API, banco, contratos). A interface mostra "Cliente". | Renomear exigiria migrar dados e quebrar contratos sem ganho funcional. Pode ser feito depois em uma migração própria. |
| 2 | Política de permissões em um único lugar (`policy.dart`), com negação por padrão. | Evita `if (role == ...)` espalhado e permite testar a matriz inteira em tabela. |
| 3 | Solicitação de outro cliente responde 404. | Não revela que o registro existe. É a mesma resposta de "não existe", e há teste comparando as duas. |
| 4 | O filtro por dono continua no repositório (`WHERE buyer_id`) para listagens e a checagem de dono acontece antes de devolver um registro. | Defesa em duas camadas. |
| 5 | Papel e permissões vêm do servidor (`/v1/me`); a interface só os representa. | O Flutter não é fronteira de segurança. |
| 6 | Tokens `demo-*` só em development; fora disso `DenyAllIdentityVerifier`. Login Google continua pendente (ver PERMISSIONS.md). | Separação já imposta pela configuração e coberta por teste. |
| 7 | Material nunca é apagado: desativar é `active = false`. | Preserva histórico e referências. |
| 8 | Orçamentos antigos guardam snapshot (nome, unidade, custo unitário, total em centavos) em `quote_pricing_items`, criado na migração 002. Editar ou desativar material não toca esses campos. | Histórico imutável. Há teste PostgreSQL que altera o material e confere o snapshot. |
| 9 | Custo unitário trafega como texto decimal (`"13.333333"`) e é gravado via `::text::numeric`, nunca `double`. Aceita até 8 dígitos inteiros e 6 decimais (`NUMERIC(14,6)`). | Regra do projeto: dinheiro sem ponto flutuante. |
| 10 | Duplicidade é nome + unidade sem diferenciar maiúsculas (índice único da migração 002) e responde 409. | Evita o mesmo material duas vezes no catálogo. |
| 11 | `GET /v1/quote-requests/{id}/pdf` existe só como **barreira de acesso** (401/403/404 e, se autorizado, 501). | A geração de PDF depende de propostas, que não existem. Quando existir, o arquivo é gerado depois da checagem. |
| 12 | Migração `003_admin_role.sql` apenas amplia o `CHECK` de `users.role`. | Aditiva; não altera dados. |
