# Database migrations — S3-00

Requires Python 3 and either Docker Compose or a local PostgreSQL `psql` client.

From repository root, start the database and run migrations before starting the API:

```sh
docker compose up -d --wait db
python3 scripts/migrate.py
docker compose up -d --build --wait api
```

On Windows, use `python` instead of `python3`, or run `scripts/demo.ps1`.
For local psql, configure PGHOST, PGPORT, PGUSER, PGDATABASE and PGPASSWORD, then use
`python3 scripts/migrate.py --psql`. Credentials must not be committed.

## Adding migrations

Create `database/migrations/002_descriptive_name.sql`, followed by 003, etc.
Use UTF-8, unique numeric prefixes and transactional PostgreSQL SQL. Do not use
BEGIN/COMMIT/ROLLBACK, psql directives, VACUUM, or CREATE INDEX CONCURRENTLY.
The runner owns a single transaction for all pending files. Do not modify or remove
already applied files: add a new migration to correct them. No destructive volume
reset is needed. This mechanism does not make destructive SQL safe: review future
schema changes and maintain backward compatibility with the running API.

`public.schema_migrations` records file name, application time and SHA-256 checksum.
An advisory transaction lock serializes runners. A failed migration rolls back all
pending work in that invocation and returns a nonzero exit status. Applied files
are skipped; modified or missing historical files are rejected. The existing
001_initial.sql registry can be adopted once without recreating existing tables.
The historical BEGIN/COMMIT wrapper in 001 is retained in the source but stripped
in memory by the runner. Other migrations must not include transaction control.

## Deployment

The server-specific Compose file must NOT mount migrations at
`/docker-entrypoint-initdb.d`: the runner is the sole owner of initialization.
Install `scripts/deploy-dev.sh` as root-owned `/usr/local/bin/deploy-fera-dev`.
It serializes deployments, starts PostgreSQL, makes a private custom-format dump
in `/var/backups/fera-dev`, validates the dump directory with pg_restore, applies
migrations, then updates application containers and checks HTTP health.
Failures before container update stop publication. No automatic rollback of a
successful schema migration is attempted if a later application build fails.
Backups are retained; monitor available disk space and manage retention separately.

## Integration verification

```sh
python3 scripts/test_migrations.py --container fera-dev-db-1
```

This requires Docker access and CREATE DATABASE privileges, creates an isolated
randomly named database, and removes it afterward. It verifies empty initialization,
repeat execution, preservation of old data, legacy registry adoption, pending
updates, checksum mismatch, missing historical files, and transactional rollback
with interruption of subsequent migrations. It never tests against the application
database. CI also runs this suite in its temporary PostgreSQL service.
