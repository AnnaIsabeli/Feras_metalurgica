# Administração de acessos

O painel é acessível em **Conta → Administração**, no domínio público. Não exige Tailscale. Administrador e vendedor são permissões independentes; a conta Google não pode escolher nem enviar permissões no cadastro.

## Fluxo

1. Um administrador autenticado informa e-mail Google, perfil e motivo, e confirma a autorização.
2. Vendedor já cadastrado recebe a permissão imediatamente. Para uma conta ainda ausente, a autorização é aplicada no primeiro login Google com o e-mail confirmado. A autorização pendente expira em sete dias. O painel não envia e-mails automaticamente.
3. Administrador convidado entra com sua própria conta e configura seu próprio autenticador. O convite sozinho não libera o painel.
4. Google + código TOTP liberam uma sessão administrativa de cinco minutos. Convites de administrador exigem que essa confirmação tenha ocorrido nos últimos dois minutos.

## Proteções

- Identidade Google verificada criptograficamente; permissões consultadas no banco a cada requisição.
- Segundo fator individual RFC6238, 30 segundos, seis dígitos, tolerância de um passo e proteção contra reutilização.
- Segredos TOTP criptografados com AES-256-GCM e identificador da conta como dados autenticados. A chave mestra não fica no banco ou Git.
- Cinco tentativas inválidas bloqueiam novos desbloqueios por quinze minutos; sessões têm limite de requisições e expiração no servidor.
- Token administrativo aleatório de 256 bits, armazenado apenas por hash no banco e apenas em memória na interface. Exige também o token Google da mesma conta.
- Autorização de alterações dentro de transação, verificação de administrador ativo, parâmetros SQL, campos permitidos, identificador idempotente e auditoria.
- Nada de cookies administrativos ou tokens em URL/localStorage. Respostas não devem ser armazenadas em cache. Origem administrativa do navegador limitada a `https://orcex.shop`.
- Configuração do autenticador só é entregue ao próprio convidado, com prazo de dez minutos. Depois de ativada, o segredo não pode ser recuperado/resetado pelo endpoint público.
- A aplicação não administra contas Google, senhas Google ou acesso SSH ao servidor.

## Configuração pelo operador

1. Aplique as migrations pelo processo normal, com backup verificado.
2. Gere `ADMIN_MFA_KEY` com 32 bytes aleatórios codificados em base64, em arquivo protegido do servidor. Não imprima a chave em logs, não a envie ao chat e não a comite. Inclua a variável no ambiente do serviço `api`. Guarde cópia em cofre protegido separado do backup do banco. A perda da chave exige recadastrar os autenticadores.
3. O recurso fica desativado sem essa variável. A aplicação recusa combiná-la com autenticação de demonstração ou sem Google configurado.
4. Para o primeiro administrador, com a conta Google já registrada, execute no servidor:

   `sudo python3 scripts/bootstrap_admin.py --email EMAIL_AUTORIZADO --reason 'Autorização explícita do responsável pelo projeto'`

   Esse procedimento só cria o convite inicial, não configura MFA nem cria sessão. Ele recusa execução se já existir administrador ativo.
5. O titular entra novamente no site, abre Conta → Administração e configura/confirma pessoalmente seu aplicativo autenticador. Nunca compartilhe QR, chave ou códigos.
6. Configure o proxy para impedir enquadramento da página por outros sites (`Content-Security-Policy: frame-ancestors 'none'`) e mantenha HTTPS e autenticação demonstrativa desativada.

## Recuperação e suspensão

Não há endpoint público para redefinir MFA ou suspender outros administradores nesta entrega. Recuperação de acesso exige o operador autorizado pelo SSH. Para suspender uma conta administrativa, desabilite seu registro em `admin_accounts` e remova suas sessões em `admin_sessions`, dentro de transação; não altere o vínculo Google ou outros usuários. Convites ainda não aceitos desse administrador deixam de ser aplicáveis. Preserve a auditoria e realize backup antes da intervenção.

## Endpoints

Todos exigem Google verificado; os acessos são revalidados no servidor.

| Endpoint | Exigência adicional |
| --- | --- |
| `POST /v1/admin/enrollment` | Convite válido e login Google recente; somente a própria conta ainda não ativada |
| `POST /v1/admin/session` | Login recente + TOTP, conta habilitada e convite ainda válido na primeira ativação |
| `GET /v1/admin/overview` | Sessão MFA válida |
| `POST /v1/admin/invitations` | Sessão MFA válida, confirmação no cliente e comando validado/idempotente |
| `POST /v1/admin/lock` | Sessão MFA válida; encerra a própria sessão |

## Validação

`admin_crypto_test.dart` cobre os vetores SHA1 do RFC6238 e integridade/vínculo da criptografia. `admin_security_postgres_test.dart` cobre negação de acesso, reutilização/bloqueio de códigos, expiração/revogação de sessão, isolamento entre contas, convites e ativação individual. `admin_http_test.dart` cobre acesso público sem credenciais, vendedor, ausência de MFA, origem e recurso desligado. Os testes Flutter verificam confirmação antes de enviar autorização e remoção do painel ao expirar a sessão.

MFA reduz riscos de credencial roubada, mas TOTP pode ser alvo de phishing. Ninguém deve informar códigos em mensagens ou aprovar acessos sem conferir o e-mail e o motivo. Passkeys, recuperação autônoma e remoção de administradores pelo painel não fazem parte desta entrega.
