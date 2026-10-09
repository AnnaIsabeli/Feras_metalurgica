#!/usr/bin/env bash
# Integration tests: ONLY run against an empty, disposable PostgreSQL database.
set -euo pipefail
: "${DATABASE_URL:?Defina DATABASE_URL para um banco de teste vazio}"
database_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
query() { psql "$DATABASE_URL" -X -w -At -v ON_ERROR_STOP=1 -c "$1"; }
assert() {
  [[ "$(query "$1")" == "$2" ]] || {
    echo "Falhou: $1 (esperado: $2)" >&2
    exit 1
  }
}

# Refuse an existing application database before performing any writes.
assert "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE'" 0

fixture_dir="$(mktemp -d)"
trap 'rm -rf -- "$fixture_dir"' EXIT
cp "$database_dir/migrate.sh" "$fixture_dir/migrate.sh"
mkdir "$fixture_dir/migrations"
cp "$database_dir"/migrations/*.sql "$fixture_dir/migrations/"

# Empty database: run from a different working directory.
(cd "$fixture_dir" && bash ./migrate.sh)
assert "SELECT count(*) FROM public.schema_migrations WHERE version = '001_initial.sql'" 1
query "INSERT INTO users (id,email,display_name,role) VALUES ('00000000-0000-4000-8000-000000000099','migration-test@example.invalid','Migration test','buyer');
INSERT INTO quote_requests (id,buyer_id,product,description,quantity) VALUES ('00000000-0000-4000-8000-000000000099','00000000-0000-4000-8000-000000000099','Test','Preserve this row',1);" >/dev/null

# Baseline/existing database and repeated runs: do not change applied_at or data.
before="$(query "SELECT version || '|' || applied_at FROM public.schema_migrations ORDER BY version")"
bash "$fixture_dir/migrate.sh"
bash "$fixture_dir/migrate.sh"
[[ "$(query "SELECT version || '|' || applied_at FROM public.schema_migrations ORDER BY version")" == "$before" ]]
assert "SELECT description FROM quote_requests WHERE id = '00000000-0000-4000-8000-000000000099'" "Preserve this row"

# Pending migrations in lexicographic order; concurrent runs apply each only once.
cat > "$fixture_dir/migrations/010_test.sql" <<'SQL'
CREATE TABLE migration_runner_test (value integer NOT NULL);
INSERT INTO migration_runner_test VALUES (1);
SQL
cat > "$fixture_dir/migrations/020_test.sql" <<'SQL'
INSERT INTO migration_runner_test SELECT value + 1 FROM migration_runner_test;
SQL
bash "$fixture_dir/migrate.sh" > "$fixture_dir/first.log" 2>&1 &
first_pid=$!
bash "$fixture_dir/migrate.sh" > "$fixture_dir/second.log" 2>&1 &
second_pid=$!
wait "$first_pid"
wait "$second_pid"
assert "SELECT string_agg(value::text, ',' ORDER BY value) FROM migration_runner_test" "1,2"

# A failing migration must roll back DDL/DML, remain unregistered, and stop.
cat > "$fixture_dir/migrations/030_fail.sql" <<'SQL'
CREATE TABLE migration_runner_rollback_test (value integer);
INSERT INTO migration_runner_test VALUES (3);
SELECT 1 / 0;
SQL
cat > "$fixture_dir/migrations/040_never.sql" <<'SQL'
INSERT INTO migration_runner_test VALUES (4);
SQL
if bash "$fixture_dir/migrate.sh" > "$fixture_dir/failure.log" 2>&1; then
  echo "Erro: migration inválida terminou com sucesso." >&2
  exit 1
fi
assert "SELECT to_regclass('public.migration_runner_rollback_test') IS NULL" t
assert "SELECT count(*) FROM public.schema_migrations WHERE version IN ('030_fail.sql','040_never.sql')" 0
assert "SELECT string_agg(value::text, ',' ORDER BY value) FROM migration_runner_test" "1,2"
assert "SELECT description FROM quote_requests WHERE id = '00000000-0000-4000-8000-000000000099'" "Preserve this row"

# Repair the failed fixture and prove that the next invocation can proceed.
cat > "$fixture_dir/migrations/030_fail.sql" <<'SQL'
INSERT INTO migration_runner_test VALUES (3);
SQL
bash "$fixture_dir/migrate.sh"
assert "SELECT string_agg(value::text, ',' ORDER BY value) FROM migration_runner_test" "1,2,3,4"

# Remove only disposable test fixtures; keep the real 001 and its baseline.
query "DROP TABLE migration_runner_test;
DELETE FROM public.schema_migrations WHERE version IN ('010_test.sql','020_test.sql','030_fail.sql','040_never.sql');
DELETE FROM quote_requests WHERE id = '00000000-0000-4000-8000-000000000099';
DELETE FROM users WHERE id = '00000000-0000-4000-8000-000000000099';" >/dev/null
echo "Testes de migrations passaram."
