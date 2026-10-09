# Migrations PostgreSQL — S3-00

## Uso

Requisitos: Bash e cliente PostgreSQL (`psql`, versão 10 ou superior).
Configure `DATABASE_URL` para o banco desejado e execute:

```bash
bash database/migrate.sh
```

O runner resolve a pasta de migrations a partir do próprio script, usa ordem
lexicográfica com locale C e registra o nome completo, por exemplo
`001_initial.sql`. A tabela `public.schema_migrations` é criada se necessário,
com `version text PRIMARY KEY` e `applied_at timestamptz DEFAULT now()`.
O baseline DEV existente é preservado: a 001 já registrada será pulada.

Cada migration e seu registro executam na mesma transação. Um erro aborta o
runner com código diferente de zero e desfaz a migration atual; migrations
anteriores concluídas continuam aplicadas. Um advisory lock serializa as
transações de runners concorrentes e a consulta à versão ocorre sob esse lock.
`-X` ignora configurações locais do psql e `ON_ERROR_STOP=1` interrompe em erro.

As migrations devem conter SQL transacional, sem `BEGIN`, `COMMIT`, `ROLLBACK`
ou comandos psql que alterem a conexão ou encerrem o processo. Operações como
`CREATE INDEX CONCURRENTLY` não são compatíveis com este runner.
Os nomes devem usar somente letras ASCII, números, ponto, hífen e underscore,
terminando em `.sql`; use prefixos de largura fixa para manter a ordem.
Não renomeie migrations aplicadas. O runner não verifica checksums.

Foram removidos apenas os delimitadores BEGIN/COMMIT da 001 para que seu SQL e
o registro possam ser atômicos; as tabelas e índices permanecem iguais.
Nenhuma 002 foi criada. Seeds são executados separadamente pelo CI.

## Testes automatizados

O CI executa `database/test-migrate.sh` no PostgreSQL descartável do job:
banco vazio, repetição, dados existentes, ordem, concorrência, rollback,
interrupção e retomada após correção. O teste recusa um banco com tabelas em
public. Não execute esse teste no DEV: ele cria e remove fixtures de teste.

```bash
# DATABASE_URL deve apontar para um banco vazio e descartável.
bash database/test-migrate.sh
```

## Banco DEV existente e repetição

Com o backup já feito, confirme que está conectado ao DEV e que a 001 está
registrada. Use a URL DEV em um cliente com acesso ao banco; não suponha que o
hostname `db` do Compose seja acessível a partir do host. Não divulgue a senha.

```bash
psql "$DATABASE_URL" -X -w -v ON_ERROR_STOP=1 -c \
  "SELECT current_database(); SELECT * FROM public.schema_migrations ORDER BY version;"
```

Capture dados completos e registros de versões antes e depois. Estes arquivos
contêm dados do banco; guarde-os fora do repositório:

```bash
CHECK_DIR="$(mktemp -d)"
pg_dump "$DATABASE_URL" --data-only --table=public.users --table=public.quote_requests \
  > "$CHECK_DIR/data-before.sql"
psql "$DATABASE_URL" -X -w -At -v ON_ERROR_STOP=1 -c \
  "SELECT version, applied_at FROM public.schema_migrations ORDER BY version" \
  > "$CHECK_DIR/versions-before.txt"

bash database/migrate.sh
bash database/migrate.sh

pg_dump "$DATABASE_URL" --data-only --table=public.users --table=public.quote_requests \
  > "$CHECK_DIR/data-after.sql"
psql "$DATABASE_URL" -X -w -At -v ON_ERROR_STOP=1 -c \
  "SELECT version, applied_at FROM public.schema_migrations ORDER BY version" \
  > "$CHECK_DIR/versions-after.txt"

diff -u "$CHECK_DIR/versions-before.txt" "$CHECK_DIR/versions-after.txt"
diff -u "$CHECK_DIR/data-before.sql" "$CHECK_DIR/data-after.sql"
```

Esperado: ambas as execuções pulam a 001, preservando seu applied_at e os dados.
Suspenda escritas da aplicação durante essa comparação para evitar diferenças
legítimas. Versões recentes do pg_dump podem gerar tokens aleatórios nas linhas
`\\restrict` / `\\unrestrict`; desconsidere somente essas linhas ao comparar.

Como o Compose do servidor é local, uma alternativa para executar com o cliente
já instalado no container db é copiar os arquivos para uma pasta temporária.
Confirme que o container possui Bash antes; não altere o volume do banco:

```bash
cd /home/antiserver/fera-metalurgica
sudo docker compose -f compose.server.yaml exec -T db bash --version
sudo docker compose -f compose.server.yaml cp database db:/tmp/fera-s3-00
sudo docker compose -f compose.server.yaml exec -T db bash -c \
  'export DATABASE_URL="postgresql://$POSTGRES_USER@localhost:5432/$POSTGRES_DB"; export PGPASSWORD="$POSTGRES_PASSWORD"; bash /tmp/fera-s3-00/migrate.sh'
```

Essa alternativa pressupõe POSTGRES_USER, POSTGRES_DB e POSTGRES_PASSWORD no
container e autenticação local compatível. Rode o último comando novamente
para verificar a repetição. Para consultas/dumps no container, use
`exec -T db psql -U fera -d fera ...` e `exec -T db pg_dump -U fera -d fera ...`.
Não rode os seeds no DEV para validar o runner.

## Banco vazio

Crie um banco separado, sem reutilizar o DEV nem remover volumes.
Com uma conexão administrativa de teste em `TEST_ADMIN_URL`:

```bash
createdb --maintenance-db="$TEST_ADMIN_URL" fera_migrations_s3_00
```

Configure DATABASE_URL para esse novo banco, usando host/usuário/senha corretos:

```bash
bash database/migrate.sh
psql "$DATABASE_URL" -X -w -v ON_ERROR_STOP=1 -c \
  "SELECT * FROM public.schema_migrations; SELECT count(*) FROM users; SELECT count(*) FROM quote_requests;"
bash database/migrate.sh
```

Esperado: tabelas criadas, 001 registrada uma única vez, zero registros de
negócio e segunda execução pulando a 001. Para testar uma pendência e erro,
use o teste automatizado no banco vazio em vez de inventar uma 002 real.

O Compose versionado ainda inicializa SQL via docker-entrypoint-initdb.d e
não registra versões. Por isso, para este teste vazio, use um banco criado
com createdb ou um PostgreSQL isolado sem esse mount. Um banco já inicializado
por Docker exige baseline verificado antes de usar o runner; ele não tenta
adivinhar quais migrations já foram executadas.

## Integração com deploy DEV

O CI agora usa o runner, seguido dos seeds no banco de testes.
O deploy chama `/usr/local/bin/deploy-fera-dev`, que está apenas no servidor,
assim como compose.server.yaml. A integração do script externo deve executar
o runner depois de atualizar o checkout e iniciar/aguardar o db, antes de
subir a nova API. Use uma URL acessível ou a execução no container acima.
O script de deploy deve usar `set -e` e abortar se o runner falhar.

Este PR não altera nem executa o script externo do servidor e não faz deploy.
Nenhum comando exige apagar banco ou usar `docker compose down -v`.
