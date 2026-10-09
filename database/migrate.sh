#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

: "${DATABASE_URL:?Defina DATABASE_URL para o banco de destino}"
command -v psql >/dev/null 2>&1 || {
  echo "Erro: psql não está instalado." >&2
  exit 1
}

# Resolve paths relative to this script, independent of the caller's directory.
database_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd -- "$database_dir/migrations"
shopt -s nullglob
migrations=(*.sql)

# Keep names safe for psql's \ir command; sort is Bash glob order under LC_ALL=C.
for migration in "${migrations[@]}"; do
  if [[ ! "$migration" =~ ^[a-zA-Z0-9_.-]+\.sql$ || ! -f "$migration" ]]; then
    echo "Erro: nome de migration inválido: $migration" >&2
    exit 1
  fi
done

# All runner instances use the same transaction-level advisory lock.
psql "$DATABASE_URL" -X -w -v ON_ERROR_STOP=1 <<'SQL'
BEGIN;
SELECT pg_advisory_xact_lock(73420000);
CREATE TABLE IF NOT EXISTS public.schema_migrations (
  version text PRIMARY KEY,
  applied_at timestamptz NOT NULL DEFAULT now()
);
COMMIT;
SQL

for migration in "${migrations[@]}"; do
  echo "Verificando $migration"
  # Check again under the lock, so concurrent runners cannot apply it twice.
  # The SQL and its version record commit together; errors roll both back.
  psql "$DATABASE_URL" -X -w -v ON_ERROR_STOP=1 -v "version=$migration" <<SQL
BEGIN;
SELECT pg_advisory_xact_lock(73420000);
SELECT EXISTS (
  SELECT 1 FROM public.schema_migrations WHERE version = :'version'
) AS already_applied \gset
\if :already_applied
  \echo 'Já aplicada:' :version
\else
  \echo 'Aplicando:' :version
  \ir '$migration'
  INSERT INTO public.schema_migrations (version) VALUES (:'version');
\endif
COMMIT;
SQL
done

echo "Migrations concluídas."
