-- S3-01: catálogo de materiais e precificações salvas com snapshot de custos.
-- Migration apenas aditiva: não altera nem remove tabelas existentes.
-- Convenção do projeto: totais em centavos inteiros; custo unitário de material em NUMERIC.

CREATE TABLE materials (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name varchar(120) NOT NULL CHECK (length(trim(name)) > 0),
  unit varchar(30) NOT NULL CHECK (length(trim(unit)) > 0),
  unit_cost numeric(14,6) NOT NULL CHECK (unit_cost >= 0),
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX materials_name_unit_uidx ON materials (lower(trim(name)), lower(trim(unit)));

CREATE TABLE quote_pricings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quote_request_id uuid NOT NULL REFERENCES quote_requests(id),
  created_by uuid REFERENCES users(id),
  total_price_cents bigint NOT NULL CHECK (total_price_cents >= 0),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX quote_pricings_request_created_idx ON quote_pricings (quote_request_id, created_at DESC);

CREATE TABLE quote_pricing_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quote_pricing_id uuid NOT NULL REFERENCES quote_pricings(id) ON DELETE CASCADE,
  -- Referência ao catálogo; o snapshot abaixo garante o histórico mesmo se o material mudar ou sair.
  material_id uuid REFERENCES materials(id) ON DELETE SET NULL,
  material_name_snapshot varchar(120) NOT NULL CHECK (length(trim(material_name_snapshot)) > 0),
  unit_snapshot varchar(30) NOT NULL CHECK (length(trim(unit_snapshot)) > 0),
  quantity numeric(12,3) NOT NULL CHECK (quantity > 0),
  unit_cost_snapshot numeric(14,6) NOT NULL CHECK (unit_cost_snapshot >= 0),
  line_total_cents bigint NOT NULL CHECK (line_total_cents >= 0),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX quote_pricing_items_pricing_idx ON quote_pricing_items (quote_pricing_id);
CREATE INDEX quote_pricing_items_material_idx ON quote_pricing_items (material_id);
