-- Local demonstration only: loaded by scripts/demo.ps1, never by production bootstrap.
INSERT INTO users(id,email,display_name,role,seller_approved) VALUES
('00000000-0000-4000-8000-000000000001','buyer@example.invalid','Comprador demonstração','buyer',false),
('00000000-0000-4000-8000-000000000002','seller@example.invalid','Vendedor demonstração','seller',true)
ON CONFLICT (id) DO NOTHING;
