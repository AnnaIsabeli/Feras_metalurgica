-- DEMONSTRAÇÃO: valores do gerador S3-02/KAN-32 (database/catalogo/catalogo_materiais.csv),
-- ainda NÃO conferidos com a empresa. O catálogo real deve ser cadastrado pela tela de
-- Catálogo (perfil Administrador) depois de conferido. Não carregar em produção.
INSERT INTO materials(name, unit, unit_cost) VALUES
('Metalon 40x30', 'metro', 13.333333),
('Eletrodo', 'kg', 25.000000),
('Tinta', 'litro', 20.000000)
ON CONFLICT DO NOTHING;
