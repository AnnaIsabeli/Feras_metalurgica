BEGIN;
-- A customer received through WhatsApp does not need a users account.
ALTER TABLE quote_requests ALTER COLUMN buyer_id DROP NOT NULL;
ALTER TABLE quote_requests ADD COLUMN created_by uuid REFERENCES users(id);
ALTER TABLE quote_requests ADD COLUMN customer_name varchar(120);
ALTER TABLE quote_requests ADD COLUMN customer_contact varchar(120);
UPDATE quote_requests SET created_by = buyer_id;
ALTER TABLE quote_requests ALTER COLUMN created_by SET NOT NULL;
ALTER TABLE quote_requests ADD CONSTRAINT quote_requests_customer_required CHECK (
  buyer_id IS NOT NULL OR (customer_name IS NOT NULL AND length(trim(customer_name)) > 0)
);
CREATE INDEX quote_requests_created_by_idx ON quote_requests(created_by);
COMMIT;
