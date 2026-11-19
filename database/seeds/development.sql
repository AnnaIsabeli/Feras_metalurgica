-- Local demonstration only: loaded by scripts/demo.ps1, never by production bootstrap.
-- Contas de demonstração (tokens demo-* só funcionam em APP_ENV=development):
--   ...0001 Cliente | ...0002 Vendedor aprovado | ...0003 Administrador
--   ...0004 Vendedor NÃO aprovado | ...0005 Outro cliente (teste de isolamento)
INSERT INTO users(id,email,display_name,role,seller_approved) VALUES
('00000000-0000-4000-8000-000000000001','buyer@example.invalid','Cliente demonstração','buyer',false),
('00000000-0000-4000-8000-000000000002','seller@example.invalid','Vendedor demonstração','seller',true),
('00000000-0000-4000-8000-000000000003','admin@example.invalid','Administrador demonstração','admin',false),
('00000000-0000-4000-8000-000000000004','seller-pending@example.invalid','Vendedor pendente demonstração','seller',false),
('00000000-0000-4000-8000-000000000005','buyer2@example.invalid','Outro cliente demonstração','buyer',false)
ON CONFLICT (id) DO NOTHING;
