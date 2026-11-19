#!/usr/bin/env python3
"""Apply ordered PostgreSQL migrations atomically using psql (direct or Compose)."""
import argparse
import hashlib
from pathlib import Path
import re
import subprocess
import sys


def literal(value):
    return "'" + value.replace("'", "''") + "'"


def build_sql(folder):
    files = sorted(folder.glob('*.sql'), key=lambda p: (int(p.name.split('_')[0]) if p.name.split('_')[0].isdigit() else -1, p.name))
    if not files:
        raise ValueError('No SQL migrations found')
    versions = set()
    migrations = []
    for path in files:
        match = re.fullmatch(r'(\d{3,})_[a-z0-9_]+\.sql', path.name)
        if not match or match[1] in versions:
            raise ValueError(f'Invalid or duplicate migration version: {path.name}')
        versions.add(match[1])
        body = path.read_text(encoding='utf-8')
        # Preserve the historical file/checksum while taking ownership of its transaction.
        if path.name == '001_initial.sql':
            body = re.sub(r'\ABEGIN;\s*', '', body)
            body = re.sub(r'\s*COMMIT;\s*\Z', '', body)
        if re.search(r'^\s*\\|\b(BEGIN|COMMIT|ROLLBACK|VACUUM)\b|\bCONCURRENTLY\b', body, re.I | re.M):
            raise ValueError(f'{path.name}: use transactional SQL without transaction commands or psql directives')
        migrations.append((path.name, hashlib.sha256(path.read_bytes()).hexdigest(), body))
    names = ','.join(literal(name) for name, _, _ in migrations)
    sql = [r'\set ON_ERROR_STOP on', 'BEGIN;', "SET LOCAL lock_timeout = '60s';",
           "SELECT pg_advisory_xact_lock(72603000);",
           'CREATE TABLE IF NOT EXISTS public.schema_migrations (version text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now());',
           'ALTER TABLE public.schema_migrations ADD COLUMN IF NOT EXISTS checksum text;',
           f"DO $$ BEGIN IF EXISTS (SELECT 1 FROM public.schema_migrations WHERE version NOT IN ({names})) THEN RAISE EXCEPTION 'Database has migrations missing from this checkout'; END IF; END $$;"]
    for name, digest, body in migrations:
        n, h = literal(name), literal(digest)
        # Only the pre-existing initial migration may be adopted without a checksum.
        adopt = 'TRUE' if name == '001_initial.sql' else 'FALSE'
        sql += [f"DO $$ BEGIN IF EXISTS (SELECT 1 FROM public.schema_migrations WHERE version={n} AND (checksum <> {h} OR (checksum IS NULL AND NOT {adopt}))) THEN RAISE EXCEPTION 'Applied migration changed or has no checksum: {name}'; END IF; END $$;",
                f'SELECT NOT EXISTS (SELECT 1 FROM public.schema_migrations WHERE version={n}) AS pending \\gset',
                r'\if :pending', f'\\echo Applying {name}', body,
                f'INSERT INTO public.schema_migrations(version,checksum) VALUES ({n},{h});',
                r'\else', f'\\echo Already applied: {name}',
                f'UPDATE public.schema_migrations SET checksum={h} WHERE version={n} AND checksum IS NULL;', r'\endif']
    sql += ['COMMIT;', r'\echo Migrations complete.']
    return '\n'.join(sql) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', type=Path, default=Path(__file__).resolve().parents[1] / 'database/migrations')
    parser.add_argument('--compose-file', default='compose.yaml')
    parser.add_argument('--psql', action='store_true', help='Use local psql and PG* environment variables')
    args = parser.parse_args()
    try:
        sql = build_sql(args.directory)
        command = ['psql', '-X', '-v', 'ON_ERROR_STOP=1'] if args.psql else [
            'docker', 'compose', '-f', args.compose_file, 'exec', '-T', 'db',
            'sh', '-c', 'exec psql -X -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"']
        return subprocess.run(command, input=sql, text=True).returncode
    except (ValueError, OSError) as exc:
        print(f'Migration failed: {exc}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
