-- Administrator eligibility is provisioned out of band, never by the public API.
CREATE TABLE admin_accounts (
  user_id uuid PRIMARY KEY REFERENCES users(id),
  totp_encrypted text NOT NULL,
  enabled boolean NOT NULL DEFAULT true,
  activated_at timestamptz,
  enrollment_expires_at timestamptz,
  last_counter bigint NOT NULL DEFAULT -1,
  failed_attempts integer NOT NULL DEFAULT 0 CHECK (failed_attempts >= 0),
  blocked_until timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE admin_sessions (
  token_hash text PRIMARY KEY CHECK (length(token_hash)=64),
  user_id uuid NOT NULL REFERENCES admin_accounts(user_id) ON DELETE CASCADE,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  window_started_at timestamptz NOT NULL DEFAULT now(),
  request_count integer NOT NULL DEFAULT 0
);
CREATE INDEX admin_sessions_user ON admin_sessions(user_id);
CREATE TABLE admin_audit_events (
  id uuid PRIMARY KEY,
  actor_id uuid REFERENCES admin_accounts(user_id),
  target_id uuid REFERENCES users(id),
  action text NOT NULL CHECK (action IN ('mfa_activated','session_opened','mfa_rejected','seller_approved','seller_revoked','seller_invited','admin_invited','invitation_cancelled')),
  reason text,
  before_state jsonb,
  after_state jsonb,
  command_id uuid UNIQUE,
  command_hash text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX admin_audit_time ON admin_audit_events(created_at DESC,id);

CREATE TABLE access_invitations (
  email text NOT NULL CHECK (email=lower(email)),
  role text NOT NULL CHECK (role IN ('seller','admin')),
  invited_by uuid REFERENCES admin_accounts(user_id),
  reason text NOT NULL,
  PRIMARY KEY(email,role),
  expires_at timestamptz NOT NULL,
  accepted_by uuid REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);
