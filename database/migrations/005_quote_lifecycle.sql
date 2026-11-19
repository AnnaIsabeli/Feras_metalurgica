-- Preserve legacy requests; saved quotations start awaiting a decision.
ALTER TABLE quote_requests DROP CONSTRAINT quote_requests_status_check;
UPDATE quote_requests SET status = CASE WHEN status='closed' THEN 'completed' WHEN status='quoted' OR EXISTS (SELECT 1 FROM quote_pricings p WHERE p.quote_request_id=quote_requests.id) THEN 'pending' ELSE status END;
ALTER TABLE quote_requests ADD CONSTRAINT quote_requests_status_check CHECK (status IN ('received','needsInformation','drafting','pending','approved','rejected','inProduction','completed','cancelled'));
