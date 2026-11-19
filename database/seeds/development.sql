-- Local demonstration only: loaded by scripts/demo.ps1, never by production bootstrap.
INSERT INTO users(id,email,display_name,role,seller_approved) VALUES
('00000000-0000-4000-8000-000000000001','buyer@example.invalid','Comprador demonstração','buyer',false),
('00000000-0000-4000-8000-000000000002','seller@example.invalid','Vendedor demonstração','seller',true)
ON CONFLICT (id) DO NOTHING;

-- Perfis extras usados nos testes de autorização (somente desenvolvimento).
INSERT INTO users(id,email,display_name,role,seller_approved) VALUES
('00000000-0000-4000-8000-000000000003','admin@example.invalid','Administrador demonstração','admin',false),
('00000000-0000-4000-8000-000000000004','pending-seller@example.invalid','Vendedor pendente demonstração','seller',false),
('00000000-0000-4000-8000-000000000005','buyer2@example.invalid','Segundo cliente demonstração','buyer',false)
ON CONFLICT (id) DO NOTHING;
