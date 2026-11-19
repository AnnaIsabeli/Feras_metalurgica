#!/usr/bin/env python3
"""Out-of-band invitation for the first administrator; never creates active MFA."""
import argparse
import re
import subprocess
import uuid


def literal(value):
    return "'" + value.replace("'", "''") + "'"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--email', required=True)
    parser.add_argument('--reason', required=True)
    parser.add_argument('--compose-file', default='compose.server.yaml')
    args = parser.parse_args()
    email = args.email.strip().lower()
    if len(email) > 254 or not re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+', email):
        parser.error('Invalid email')
    if not 8 <= len(args.reason.strip()) <= 240:
        parser.error('Reason must contain 8–240 characters')
    email_sql, reason_sql = literal(email), literal(args.reason.strip())
    sql = f"""
BEGIN;
SELECT pg_advisory_xact_lock(hashtext('orcex-first-admin'));
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM admin_accounts WHERE enabled AND activated_at IS NOT NULL) THEN
  RAISE EXCEPTION 'An active administrator already exists; use the MFA-protected panel';
 END IF;
 IF (SELECT count(*) FROM users WHERE lower(email)={email_sql} AND google_subject IS NOT NULL) != 1 THEN
  RAISE EXCEPTION 'Exactly one Google-verified account is required';
 END IF;
END $$;
INSERT INTO access_invitations(email,role,reason,expires_at)
 VALUES({email_sql},'admin',{reason_sql},now()+interval '7 days')
 ON CONFLICT(email,role) DO UPDATE SET role='admin',invited_by=NULL,reason=EXCLUDED.reason,expires_at=EXCLUDED.expires_at,accepted_by=NULL,created_at=now();
INSERT INTO admin_audit_events(id,target_id,action,reason,after_state)
 SELECT '{uuid.uuid4()}',id,'admin_invited',{reason_sql},jsonb_build_object('email',{email_sql},'role','admin','source','operator_bootstrap') FROM users WHERE lower(email)={email_sql};
COMMIT;
"""
    subprocess.run(['docker', 'compose', '-f', args.compose_file, 'exec', '-T', 'db',
                    'sh', '-c', 'exec psql -X -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"'],
                   input=sql, text=True, check=True)
    print('Initial invitation recorded. The account must configure and confirm its own authenticator.')


if __name__ == '__main__':
    main()
