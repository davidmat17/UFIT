-- =====================================================================
-- Migración 016 — RF13: gestión administrativa de contenidos
-- Proyecto de Ingeniería de Software 1, Grupo 8, UIS
--
-- Se corre UNA vez en el SQL Editor de Supabase, sobre la base que ya
-- tiene schema.sql y las migraciones anteriores. schema.sql ya incluye
-- estos cambios, así que una base creada desde cero no necesita esta
-- migración.
--
-- Por qué existe:
--   El RF13 pide que el administrador cree, edite y dé de baja máquinas y
--   ejercicios, publique versiones nuevas de la normativa y asigne
--   instructores a días y franjas, que nadie más pueda hacerlo aunque
--   manipule la petición, y que cada cambio quede en una bitácora con
--   usuario, acción y fecha-hora (CU13).
--
-- Qué cambia:
--   1. Tabla nueva bitacora (la número 15). La escriben solo los
--      disparadores y las funciones de esta migración; la lee solo el
--      administrador.
--   2. ejercicios.activo (dar de baja sin borrar) y actualizado_en en
--      maquinas y ejercicios. Restricciones de longitud por campo (5c).
--   3. eliminar_maquina() y eliminar_ejercicio(): impiden borrar lo que
--      usan las rutinas de alguien y ofrecen dejarlo fuera de servicio
--      (5a). Se quita el DELETE directo.
--   4. publicar_normativa(): versión nueva, conserva la anterior y avisa
--      si otro administrador publicó primero (4a, 5b).
--   5. asignar_turno(): asigna o quita un instructor en varios días y
--      horas de una vez. Se quita la escritura directa en
--      asignaciones_instructor.
--   6. actualizar_persona(): rol, estado y especialidad de una persona.
--      Era lo que faltaba para cambiar roles sin entrar a Supabase.
--
-- Va después de la 015. Se puede correr más de una vez.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Bitácora de auditoría
-- ---------------------------------------------------------------------

create table if not exists public.bitacora (
  id          bigint generated always as identity primary key,
  perfil_id   uuid references public.perfiles (id) on delete set null,
  accion      text not null,
  entidad     text not null,
  entidad_id  text,
  detalle     jsonb,
  creada_en   timestamptz not null default now()
);

create index if not exists bitacora_por_fecha on public.bitacora (creada_en desc);

comment on table public.bitacora is
  'RF13: quién cambió qué y cuándo. La escriben disparadores y funciones; nadie la edita. Solo la lee el administrador.';

alter table public.bitacora enable row level security;

drop policy if exists bitacora_lectura_admin on public.bitacora;
create policy bitacora_lectura_admin on public.bitacora
  for select using (public.es_administrador());

revoke insert, update, delete on public.bitacora from anon, authenticated;

-- Escribe una línea. No se le da permiso a nadie: la usan los
-- disparadores y las funciones de abajo.
create or replace function public.anotar_en_bitacora(
  p_accion      text,
  p_entidad     text,
  p_entidad_id  text,
  p_detalle     jsonb
)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.bitacora (perfil_id, accion, entidad, entidad_id, detalle)
  values (
    -- Un cambio hecho desde el panel de Supabase no tiene sesión: queda
    -- con perfil null, pero queda.
    (select id from public.perfiles where id = auth.uid()),
    p_accion, p_entidad, p_entidad_id, p_detalle
  );
$$;

revoke all on function public.anotar_en_bitacora(text, text, text, jsonb)
  from public, anon, authenticated;

-- Disparador genérico: crear, editar y borrar. En las ediciones guarda
-- solo los campos que cambiaron.
create or replace function public.auditar_cambio()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  antes    jsonb;
  despues  jsonb;
  cambios  jsonb;
  ident    text;
begin
  if tg_op = 'INSERT' then
    despues := to_jsonb(new);
    ident := coalesce(despues ->> 'id', despues ->> 'maquina_id');
    perform public.anotar_en_bitacora('crear', tg_table_name, ident, despues);
    return new;
  elsif tg_op = 'DELETE' then
    antes := to_jsonb(old);
    ident := coalesce(antes ->> 'id', antes ->> 'maquina_id');
    perform public.anotar_en_bitacora('eliminar', tg_table_name, ident, antes);
    return old;
  end if;

  antes := to_jsonb(old);
  despues := to_jsonb(new);
  select jsonb_object_agg(d.key, jsonb_build_object('antes', antes -> d.key, 'despues', d.value))
    into cambios
    from jsonb_each(despues) d
   where antes -> d.key is distinct from d.value
     and d.key not in ('actualizado_en');

  if cambios is not null then
    ident := coalesce(despues ->> 'id', despues ->> 'maquina_id');
    perform public.anotar_en_bitacora('editar', tg_table_name, ident, cambios);
  end if;
  return new;
end;
$$;

revoke all on function public.auditar_cambio() from public, anon, authenticated;


-- ---------------------------------------------------------------------
-- 2. Máquinas y ejercicios: baja sin borrar, fecha de actualización y
--    validación por campo
-- ---------------------------------------------------------------------

alter table public.ejercicios
  add column if not exists activo boolean not null default true;
alter table public.ejercicios
  add column if not exists actualizado_en timestamptz not null default now();
alter table public.maquinas
  add column if not exists actualizado_en timestamptz not null default now();

comment on column public.ejercicios.activo is
  'RF13: false cuando el administrador lo da de baja. Deja de aparecer en el catálogo y en las rutinas nuevas; las rutinas que ya lo tienen lo conservan.';

alter table public.maquinas drop constraint if exists maquinas_nombre_longitud;
alter table public.maquinas add constraint maquinas_nombre_longitud
  check (char_length(btrim(nombre)) between 2 and 80);
alter table public.maquinas drop constraint if exists maquinas_descripcion_longitud;
alter table public.maquinas add constraint maquinas_descripcion_longitud
  check (descripcion is null or char_length(descripcion) <= 1000);
alter table public.maquinas drop constraint if exists maquinas_imagen_url_valida;
alter table public.maquinas add constraint maquinas_imagen_url_valida
  check (imagen_url is null or imagen_url ~ '^https://');

alter table public.ejercicios drop constraint if exists ejercicios_nombre_longitud;
alter table public.ejercicios add constraint ejercicios_nombre_longitud
  check (char_length(btrim(nombre)) between 2 and 80);
alter table public.ejercicios drop constraint if exists ejercicios_grupo_longitud;
alter table public.ejercicios add constraint ejercicios_grupo_longitud
  check (char_length(btrim(grupo_muscular)) between 2 and 40);
alter table public.ejercicios drop constraint if exists ejercicios_instrucciones_longitud;
alter table public.ejercicios add constraint ejercicios_instrucciones_longitud
  check (instrucciones is null or char_length(instrucciones) <= 2000);

drop trigger if exists maquinas_actualizado_en on public.maquinas;
create trigger maquinas_actualizado_en
  before update on public.maquinas
  for each row execute function public.tocar_actualizado_en();

drop trigger if exists ejercicios_actualizado_en on public.ejercicios;
create trigger ejercicios_actualizado_en
  before update on public.ejercicios
  for each row execute function public.tocar_actualizado_en();

-- Bitácora de todo lo que se haga en el catálogo y la configuración.
drop trigger if exists maquinas_auditoria on public.maquinas;
create trigger maquinas_auditoria
  after insert or update or delete on public.maquinas
  for each row execute function public.auditar_cambio();

drop trigger if exists ejercicios_auditoria on public.ejercicios;
create trigger ejercicios_auditoria
  after insert or update or delete on public.ejercicios
  for each row execute function public.auditar_cambio();

drop trigger if exists ejercicio_maquina_auditoria on public.ejercicio_maquina;
create trigger ejercicio_maquina_auditoria
  after insert or delete on public.ejercicio_maquina
  for each row execute function public.auditar_cambio();

drop trigger if exists configuracion_auditoria on public.configuracion;
create trigger configuracion_auditoria
  after update on public.configuracion
  for each row execute function public.auditar_cambio();

-- En perfiles solo interesa lo que cambia el administrador; lo que cada
-- persona edita de sí misma (RF10) no va a la bitácora.
drop trigger if exists perfiles_auditoria on public.perfiles;
create trigger perfiles_auditoria
  after update on public.perfiles
  for each row
  when (old.rol is distinct from new.rol
        or old.activo is distinct from new.activo
        or old.especialidad is distinct from new.especialidad)
  execute function public.auditar_cambio();


-- ---------------------------------------------------------------------
-- 3. Borrar sin romper rutinas (CU13, 5a)
-- ---------------------------------------------------------------------

create or replace function public.eliminar_maquina(p_maquina_id bigint)
returns table (resultado text, rutinas integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
begin
  if not public.es_administrador() then
    raise exception 'Solo el administrador puede gestionar el catálogo.'
      using errcode = '42501';
  end if;

  if not exists (select 1 from public.maquinas where id = p_maquina_id) then
    return query select 'inexistente'::text, 0;
    return;
  end if;

  select count(distinct re.rutina_id)::integer into n
    from public.rutina_ejercicios re
   where re.maquina_id = p_maquina_id;

  if n > 0 then
    return query select 'en_uso'::text, n;
    return;
  end if;

  delete from public.maquinas where id = p_maquina_id;
  return query select 'eliminada'::text, 0;
end;
$$;

create or replace function public.eliminar_ejercicio(p_ejercicio_id bigint)
returns table (resultado text, rutinas integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
begin
  if not public.es_administrador() then
    raise exception 'Solo el administrador puede gestionar el catálogo.'
      using errcode = '42501';
  end if;

  if not exists (select 1 from public.ejercicios where id = p_ejercicio_id) then
    return query select 'inexistente'::text, 0;
    return;
  end if;

  select count(distinct re.rutina_id)::integer into n
    from public.rutina_ejercicios re
   where re.ejercicio_id = p_ejercicio_id;

  if n > 0 then
    return query select 'en_uso'::text, n;
    return;
  end if;

  delete from public.ejercicios where id = p_ejercicio_id;
  return query select 'eliminado'::text, 0;
end;
$$;

revoke all on function public.eliminar_maquina(bigint) from public, anon;
grant execute on function public.eliminar_maquina(bigint) to authenticated;
revoke all on function public.eliminar_ejercicio(bigint) from public, anon;
grant execute on function public.eliminar_ejercicio(bigint) to authenticated;

-- Crear y editar siguen siendo directos (las políticas *_admin lo
-- limitan al administrador); borrar, solo con las funciones de arriba.
revoke delete on public.maquinas from anon, authenticated;
revoke delete on public.ejercicios from anon, authenticated;


-- ---------------------------------------------------------------------
-- 4. Normativa con versión (CU13, 4a y 5b)
-- ---------------------------------------------------------------------

create or replace function public.publicar_normativa(
  p_titulo        text,
  p_contenido     text,
  p_version_base  integer
)
returns table (resultado text, version integer, publicada_en timestamptz)
language plpgsql
security definer
set search_path = public
as $$
declare
  actual  public.normativa;
  nueva   public.normativa;
begin
  if not public.es_administrador() then
    raise exception 'Solo el administrador puede publicar la normativa.'
      using errcode = '42501';
  end if;

  if char_length(btrim(coalesce(p_titulo, ''))) not between 3 and 120 then
    raise exception 'El título debe tener entre 3 y 120 caracteres.';
  end if;
  if char_length(btrim(coalesce(p_contenido, ''))) not between 10 and 20000 then
    raise exception 'El contenido debe tener entre 10 y 20000 caracteres.';
  end if;

  -- Dos administradores publicando a la vez: el segundo espera aquí y
  -- luego ve la versión del primero.
  perform pg_advisory_xact_lock(hashtext('normativa'));

  select * into actual from public.normativa n
   order by n.version desc limit 1;

  if coalesce(actual.version, 0) <> coalesce(p_version_base, 0) then
    return query select 'version_cambio'::text, actual.version::integer, actual.publicada_en;
    return;
  end if;

  update public.normativa n set vigente = false where n.vigente;

  insert into public.normativa (titulo, contenido, version, vigente, publicada_por)
  values (btrim(p_titulo), btrim(p_contenido), coalesce(actual.version, 0) + 1,
          true, auth.uid())
  returning * into nueva;

  perform public.anotar_en_bitacora(
    'publicar', 'normativa', nueva.id::text,
    jsonb_build_object('version', nueva.version, 'titulo', nueva.titulo));

  return query select 'publicada'::text, nueva.version::integer, nueva.publicada_en;
end;
$$;

revoke all on function public.publicar_normativa(text, text, integer) from public, anon;
grant execute on function public.publicar_normativa(text, text, integer) to authenticated;

revoke insert, update, delete on public.normativa from anon, authenticated;


-- ---------------------------------------------------------------------
-- 5. Asignación de instructores por turno
-- ---------------------------------------------------------------------

-- Asigna (o quita, con p_instructor null) el instructor de todas las
-- franjas que caen en los días de la semana y el horario dados, dentro
-- del rango de fechas. Devuelve cuántas franjas cambió.
create or replace function public.asignar_turno(
  p_instructor  uuid,
  p_dias        smallint[],
  p_hora_desde  time,
  p_hora_hasta  time,
  p_desde       date,
  p_hasta       date
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
begin
  if not public.es_administrador() then
    raise exception 'Solo el administrador puede asignar instructores.'
      using errcode = '42501';
  end if;

  if p_dias is null or array_length(p_dias, 1) is null
     or not (p_dias <@ array[1, 2, 3, 4, 5]::smallint[]) then
    raise exception 'Elige al menos un día, de lunes a viernes.';
  end if;
  if p_hora_desde is null or p_hora_hasta is null or p_hora_hasta <= p_hora_desde then
    raise exception 'La hora final debe ser posterior a la inicial.';
  end if;
  if p_desde is null or p_hasta is null or p_hasta < p_desde then
    raise exception 'La fecha final no puede ser anterior a la inicial.';
  end if;
  if p_hasta - p_desde > 62 then
    raise exception 'Asigna como máximo 62 días a la vez.';
  end if;

  if p_instructor is not null and not exists (
    select 1 from public.perfiles
     where id = p_instructor and rol = 'instructor' and activo
  ) then
    raise exception 'La persona elegida no es un instructor activo.';
  end if;

  if p_instructor is null then
    delete from public.asignaciones_instructor a
     using public.franjas f
     where f.id = a.franja_id
       and f.fecha between p_desde and p_hasta
       and extract(isodow from f.fecha)::smallint = any (p_dias)
       and f.hora_inicio >= p_hora_desde and f.hora_inicio < p_hora_hasta;
    get diagnostics n = row_count;
  else
    insert into public.asignaciones_instructor (instructor_id, franja_id)
    select p_instructor, f.id
      from public.franjas f
     where f.fecha between p_desde and p_hasta
       and extract(isodow from f.fecha)::smallint = any (p_dias)
       and f.hora_inicio >= p_hora_desde and f.hora_inicio < p_hora_hasta
    on conflict (franja_id) do update
      set instructor_id = excluded.instructor_id,
          creada_en = now()
      where public.asignaciones_instructor.instructor_id
            is distinct from excluded.instructor_id;
    get diagnostics n = row_count;
  end if;

  perform public.anotar_en_bitacora(
    case when p_instructor is null then 'quitar_turno' else 'asignar_turno' end,
    'asignaciones_instructor', p_instructor::text,
    jsonb_build_object('dias', p_dias, 'hora_desde', p_hora_desde,
                       'hora_hasta', p_hora_hasta, 'desde', p_desde,
                       'hasta', p_hasta, 'franjas', n));
  return n;
end;
$$;

revoke all on function public.asignar_turno(uuid, smallint[], time, time, date, date) from public, anon;
grant execute on function public.asignar_turno(uuid, smallint[], time, time, date, date) to authenticated;

revoke insert, update, delete on public.asignaciones_instructor from anon, authenticated;


-- ---------------------------------------------------------------------
-- 6. Roles y estado de las personas
-- ---------------------------------------------------------------------

create or replace function public.actualizar_persona(
  p_perfil        uuid,
  p_rol           public.rol_usuario,
  p_activo        boolean,
  p_especialidad  text
)
returns text
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.es_administrador() then
    raise exception 'Solo el administrador puede cambiar roles.'
      using errcode = '42501';
  end if;

  if not exists (select 1 from public.perfiles where id = p_perfil) then
    return 'inexistente';
  end if;

  -- Quitarse a sí mismo el rol o desactivarse dejaría el sistema sin
  -- administrador si es el único.
  if p_perfil = auth.uid() and (p_rol <> 'administrador' or not p_activo) then
    return 'propia';
  end if;

  update public.perfiles
     set rol = p_rol,
         activo = p_activo,
         especialidad = case
           when p_rol = 'instructor' then nullif(btrim(p_especialidad), '')
           else null
         end
   where id = p_perfil;

  return 'actualizada';
end;
$$;

revoke all on function public.actualizar_persona(uuid, public.rol_usuario, boolean, text) from public, anon;
grant execute on function public.actualizar_persona(uuid, public.rol_usuario, boolean, text) to authenticated;
