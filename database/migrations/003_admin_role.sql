-- KAN-11: perfil Administrador (gerencia catálogo e funções administrativas).
-- Aditiva: só amplia o conjunto de papéis aceitos. A restrição
-- CHECK (role = 'seller' OR seller_approved = false) continua valendo:
-- administrador e cliente nunca têm seller_approved = true.
BEGIN;
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE users
  ADD CONSTRAINT users_role_check CHECK (role IN ('buyer','seller','admin'));
COMMIT;
