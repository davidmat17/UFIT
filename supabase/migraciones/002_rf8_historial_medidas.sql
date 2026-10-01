-- =====================================================================
-- Migración 002 — RF8 con historial de medidas antropométricas
-- Proyecto de Ingeniería de Software 1, Grupo 8, UIS
--
-- Se corre UNA vez en el SQL Editor de Supabase, sobre la base que ya
-- tiene schema.sql y la migración 001. schema.sql ya incluye estos
-- cambios, así que una base creada desde cero no necesita esta
-- migración.
--
-- Qué cambia (decisión del 1 de octubre de 2026):
--   Antes había UNA fila por persona que se sobrescribía. Ahora cada
--   medición es una fila nueva con su fecha, para poder hacer
--   seguimiento de la evolución.
--
--   1. La tabla gana un id propio y la fecha pasa a llamarse
--      registrada_en. perfil_id deja de ser la llave: una persona
--      puede tener muchas mediciones.
--   2. Peso y estatura pasan a ser obligatorios: sin ellos no hay IMC.
--   3. Una medición no se edita: se registra una nueva o se borra la
--      equivocada. La fecha la pone la base, no la app.
-- =====================================================================

-- Si algo de esto falla con "contains null values", hay filas de prueba
-- sin peso o sin estatura. Bórralas (Table Editor →
-- medidas_antropometricas) y vuelve a correrlo.

-- 1. Llave propia y fecha de la medición.
alter table public.medidas_antropometricas
  drop constraint medidas_antropometricas_pkey;

alter table public.medidas_antropometricas
  add column id bigint generated always as identity primary key;

alter table public.medidas_antropometricas
  rename column actualizado_en to registrada_en;

-- 2. Peso y estatura obligatorios.
alter table public.medidas_antropometricas
  alter column peso_kg set not null,
  alter column estatura_cm set not null;

-- La app pide el historial de una persona del más reciente al más
-- antiguo; este índice hace esa consulta directa.
create index medidas_por_perfil
  on public.medidas_antropometricas (perfil_id, registrada_en desc);

-- 3. Cada quien ve, registra y borra solo sus mediciones. No hay
--    política de edición: una medición registrada no se cambia.
drop policy if exists medidas_propias on public.medidas_antropometricas;

create policy medidas_ver_propias on public.medidas_antropometricas
  for select using (perfil_id = auth.uid());

create policy medidas_crear_propias on public.medidas_antropometricas
  for insert with check (perfil_id = auth.uid());

create policy medidas_borrar_propias on public.medidas_antropometricas
  for delete using (perfil_id = auth.uid());

-- Permisos por columna: la app no puede escribir el id ni la fecha.
revoke insert, update on public.medidas_antropometricas from anon, authenticated;
grant insert (perfil_id, peso_kg, estatura_cm, circ_cintura_cm, circ_cadera_cm,
              circ_pecho_cm, circ_brazo_cm, circ_muslo_cm)
  on public.medidas_antropometricas to authenticated;
