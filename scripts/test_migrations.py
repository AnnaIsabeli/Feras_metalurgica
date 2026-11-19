#!/usr/bin/env python3
"""Integration checks using disposable databases in an existing PostgreSQL container."""
import argparse
import shutil
import subprocess
import tempfile
import uuid
from pathlib import Path
from migrate import build_sql

p=argparse.ArgumentParser()
p.add_argument('--container', required=True)
a=p.parse_args()
name='migration_test_'+uuid.uuid4().hex[:12]

def sql(query, database=name, ok=True):
    result=subprocess.run(['docker','exec','-i',a.container,'sh','-c',
        'exec psql -X -At -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$1"','sh',database],
        input=query,text=True,capture_output=True)
    if ok and result.returncode:
        raise AssertionError(result.stderr)
    if not ok and not result.returncode:
        raise AssertionError('Expected SQL failure')
    return result.stdout.strip()

try:
    sql(f'CREATE DATABASE {name};', 'postgres')
    with tempfile.TemporaryDirectory() as temp:
        folder=Path(temp)
        original=Path(__file__).resolve().parents[1]/'database/migrations/001_initial.sql'
        shutil.copy(original,folder/original.name)
        sql(build_sql(folder))
        assert sql("SELECT count(*) FROM schema_migrations")=='1'
        print('PASS: empty database initialized')
        sql("INSERT INTO users(id,email,display_name,role) VALUES ('00000000-0000-0000-0000-000000000001','migration-test@example.invalid','Preserve me','buyer');")
        sql(build_sql(folder))
        assert sql('SELECT count(*) FROM users')=='1'
        print('PASS: rerun skips applied migration and preserves data')
        # Reproduce the legacy registry on the existing server.
        sql('ALTER TABLE schema_migrations DROP COLUMN checksum;')
        sql(build_sql(folder))
        assert sql('SELECT count(*) FROM users')=='1'
        print('PASS: legacy initial migration adopted without recreating tables')
        (folder/'002_test.sql').write_text('CREATE TABLE migration_probe(id integer PRIMARY KEY);')
        sql(build_sql(folder))
        assert sql('SELECT count(*) FROM schema_migrations')=='2'
        assert sql('SELECT count(*) FROM users')=='1'
        print('PASS: pending migration applied to populated database')
        sql(build_sql(folder))
        assert sql('SELECT count(*) FROM schema_migrations')=='2'
        print('PASS: pending migration not repeated')
        (folder/'002_test.sql').write_text('CREATE TABLE changed(id integer);')
        sql(build_sql(folder),ok=False)
        print('PASS: modified applied file rejected')
        (folder/'002_test.sql').write_text('CREATE TABLE migration_probe(id integer PRIMARY KEY);')
        (folder/'003_failure.sql').write_text('CREATE TABLE must_rollback(id integer); SELECT 1/0;')
        (folder/'004_never.sql').write_text('CREATE TABLE must_not_run(id integer);')
        sql(build_sql(folder),ok=False)
        assert sql("SELECT to_regclass('must_rollback') IS NULL AND to_regclass('must_not_run') IS NULL")=='t'
        assert sql('SELECT count(*) FROM schema_migrations')=='2'
        assert sql('SELECT count(*) FROM users')=='1'
        print('PASS: failure rolls back and stops subsequent migrations; old data intact')
        (folder/'003_failure.sql').unlink(); (folder/'004_never.sql').unlink()
        (folder/'002_test.sql').unlink()
        sql(build_sql(folder),ok=False)
        print('PASS: missing historical migration rejected')
finally:
    sql(f'DROP DATABASE IF EXISTS {name} WITH (FORCE);','postgres')
print('All migration integration checks passed; disposable database removed.')
