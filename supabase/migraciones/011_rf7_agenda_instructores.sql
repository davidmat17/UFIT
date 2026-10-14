-- =====================================================================
-- Migración 011 — RF7: consultar la disponibilidad de instructores
-- Proyecto de Ingeniería de Software 1, Grupo 8, UIS
--
-- Se corre UNA vez en el SQL Editor de Supabase, después de la 010.
-- schema.sql ya incluye estos cambios, así que una base creada desde
-- cero no la necesita. Se puede correr más de una vez.
--
-- Por qué existe:
--   El RF7 muestra, por día y franja, el nombre del instructor asignado
--   y su especialidad. Faltaban tres cosas:
--     - la especialidad no estaba guardada en ningún lado;
--     - la base dejaba poner dos instructores en la misma franja, y la
--       HU16 dice que no;
--     - un usuario no puede leer el perfil de otra persona (RLS), así
--       que no tenía cómo ver el nombre del instructor.
--
-- Qué cambia:
--   1. perfiles.especialidad (texto opcional). Solo la cambia el
--      administrador: no se agrega a los permisos de columna del usuario.
--   2. Un instructor por franja: único sobre franja_id.
--   3. Disparador: solo se puede asignar a alguien con rol instructor y
--      cuenta activa.
--   4. Sin zona: el instructor trabaja por turnos (por ejemplo de 7 a 12
--      o de 2 a 6) y está a cargo de todo el gimnasio, así que la
--      asignación ya no lleva zona (se quita asignaciones_instructor.zona_id).
--   5. Función agenda_instructores(desde, hasta): las franjas del rango
--      con su instructor, si tiene. Devuelve solo nombre, apellido y
--      especialidad del instructor; nunca el correo, el documento ni el
--      teléfono.
-- =====================================================================


-- 1. Especialidad del instructor --------------------------------------

alter table public.perfiles
  add column if not exists especialidad text;

alter table public.perfiles
  drop constraint if exists perfiles_especialidad_longitud;
alter table public.perfiles
  add constraint perfiles_especialidad_longitud
  check (especialidad is null or char_length(btrim(especialidad)) between 1 and 80);

comment on column public.perfiles.especialidad is
  'Solo para instructores: en qué acompaña (por ejemplo, "Entrenamiento funcional"). La ve el usuario en el RF7. La escribe el administrador.';


-- 2. Un instructor por franja (HU16) ----------------------------------
-- Si ya hubiera dos asignaciones en la misma franja, se deja la primera.

delete from public.asignaciones_instructor a
 using public.asignaciones_instructor b
 where a.franja_id = b.franja_id
   and a.id > b.id;

alter table public.asignaciones_instructor
  drop constraint if exists asignaciones_instructor_instructor_id_franja_id_key;
alter table public.asignaciones_instructor
  drop constraint if exists asignaciones_un_instructor_por_franja;
alter table public.asignaciones_instructor
  add constraint asignaciones_un_instructor_por_franja unique (franja_id);


-- 3. Solo instructores activos ----------------------------------------

create or replace function public.validar_asignacion_instructor()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1
      from public.perfiles p
     where p.id = new.instructor_id
       and p.rol = 'instructor'
       and p.activo
  ) then
    raise exception 'Solo se puede asignar a una persona con rol instructor y cuenta activa';
  end if;
  return new;
end;
$$;

drop trigger if exists asignaciones_solo_instructores on public.asignaciones_instructor;
create trigger asignaciones_solo_instructores
  before insert or update of instructor_id on public.asignaciones_instructor
  for each row execute function public.validar_asignacion_instructor();


-- 4. Sin zona: el instructor atiende todo el gimnasio ---------------

alter table public.asignaciones_instructor
  drop column if exists zona_id;


-- 5. La agenda que consulta el RF7 ------------------------------------
-- Se borra primero por si ya existía una versión que devolvía la zona:
-- Postgres no deja cambiar las columnas que devuelve una función.

drop function if exists public.agenda_instructores(date, date);

create function public.agenda_instructores(
  p_desde date,
  p_hasta date
)
returns table (
  franja_id     bigint,
  fecha         date,
  hora_inicio   time,
  hora_fin      time,
  abierta       boolean,
  instructor    text,
  especialidad  text
)
language sql
stable
security definer
set search_path = public
as $$
  select f.id,
         f.fecha,
         f.hora_inicio,
         f.hora_fin,
         f.estado = 'abierta',
         -- Un instructor que se desactivó o dejó de serlo no se muestra:
         -- la franja queda "sin instructor asignado".
         case when p.id is not null then p.nombre || ' ' || p.apellido end,
         case when p.id is not null then p.especialidad end
    from public.franjas f
    left join public.asignaciones_instructor a on a.franja_id = f.id
    left join public.perfiles p
           on p.id = a.instructor_id
          and p.rol = 'instructor'
          and p.activo
   where f.fecha between p_desde and p_hasta
     -- Máximo 62 días por consulta: suficiente para cualquier semana del
     -- calendario y evita que alguien pida años enteros.
     and p_hasta - p_desde <= 62
   order by f.fecha, f.hora_inicio;
$$;

comment on function public.agenda_instructores(date, date) is
  'RF7: las franjas del rango con el instructor asignado (nombre y especialidad), o null si no tiene. Solo para quien inició sesión.';

revoke all on function public.agenda_instructores(date, date) from public, anon;
grant execute on function public.agenda_instructores(date, date) to authenticated;
