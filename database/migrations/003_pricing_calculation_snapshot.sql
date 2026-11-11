-- Preserve the complete calculation, including rates and practiced price.
-- Nullable only for legacy records created before this migration.
ALTER TABLE quote_pricings ADD COLUMN calculation_snapshot jsonb;
