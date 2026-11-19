-- KAN-11: adiciona o papel administrador sem alterar registros existentes.
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE users
  ADD CONSTRAINT users_role_check CHECK (role IN ('buyer','seller','admin'));
