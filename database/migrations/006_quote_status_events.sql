CREATE TABLE quote_status_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quote_request_id uuid NOT NULL REFERENCES quote_requests(id) ON DELETE CASCADE,
  from_status text,
  to_status text NOT NULL,
  changed_by uuid NOT NULL REFERENCES users(id),
  changed_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX quote_status_events_quote_idx ON quote_status_events(quote_request_id,changed_at);
CREATE INDEX quote_requests_created_idx ON quote_requests(created_at DESC,id DESC);
