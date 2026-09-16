BEGIN;
CREATE TABLE users (
  id uuid PRIMARY KEY,
  google_subject text UNIQUE,
  email text NOT NULL UNIQUE,
  display_name text NOT NULL,
  role text NOT NULL CHECK (role IN ('buyer','seller')),
  seller_approved boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (role = 'seller' OR seller_approved = false)
);
CREATE TABLE quote_requests (
  id uuid PRIMARY KEY,
  buyer_id uuid NOT NULL REFERENCES users(id),
  product varchar(120) NOT NULL CHECK (length(trim(product)) > 0),
  description varchar(4000) NOT NULL CHECK (length(trim(description)) > 0),
  quantity integer NOT NULL CHECK (quantity BETWEEN 1 AND 10000),
  status text NOT NULL DEFAULT 'received'
    CHECK (status IN ('received','needsInformation','drafting','quoted','closed')),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX quote_requests_buyer_created_idx ON quote_requests(buyer_id, created_at DESC);
CREATE INDEX quote_requests_status_created_idx ON quote_requests(status, created_at DESC);
-- Future migrations add materials, pricing snapshots, proposal versions and orders.
-- Monetary totals must use integer cents; material unit prices need NUMERIC precision.
COMMIT;
