-- =====================================================================
-- Migración 001 — RF1 con la cuenta institucional de Microsoft
-- Proyecto de Ingeniería de Software 1, Grupo 8, UIS
--
-- Se corre UNA vez en el SQL Editor de Supabase, sobre la base que ya
-- tiene schema.sql. schema.sql ya incluye estos cambios, así que una
-- base creada desde cero no necesita esta migración.
--
-- Qué hace:
--   1. La base rechaza perfiles con correos que no sean de la UIS.
--      Microsoft deja entrar a cualquier cuenta; esta es la barrera real.
--   2. El correo del perfil tiene que ser el mismo con el que se inició
--      sesión: nadie puede registrarse con el correo de otro.
--   3. Nadie puede ponerse ni cambiarse el rol, ni desactivar su cuenta
--      desde la app. Antes, la política de edición permitía que un
--      usuario se cambiara a administrador.
-- =====================================================================

-- Si esto falla con "is violated by some row", hay perfiles de prueba
-- con correos no institucionales. Bórralos antes (Table Editor →
-- perfiles) y vuelve a correrlo.
alter table public.perfiles
  add constraint perfiles_correo_institucional
  check (lower(correo) like '%@uis.edu.co' or lower(correo) like '%@correo.uis.edu.co');

drop policy if exists perfiles_crear_propio on public.perfiles;
create policy perfiles_crear_propio on public.perfiles
  for insert with check (
    id = auth.uid()
    and lower(correo) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Permisos por columna. Las políticas de fila dicen QUÉ filas; esto dice
-- QUÉ columnas. rol, activo y correo solo se cambian desde el panel de
-- Supabase o, más adelante, con una función del administrador (RF13).
revoke insert, update on public.perfiles from anon, authenticated;
grant insert (id, nombre, apellido, documento, correo, telefono)
  on public.perfiles to authenticated;
grant update (nombre, apellido, telefono)
  on public.perfiles to authenticated;
