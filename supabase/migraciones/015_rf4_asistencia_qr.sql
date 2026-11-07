-- =====================================================================
-- Migración 015 — RF4: registro de asistencia con código QR
-- Proyecto de Ingeniería de Software 1, Grupo 8, UIS
--
-- Se corre UNA vez en el SQL Editor de Supabase, sobre la base que ya
-- tiene schema.sql y las migraciones anteriores. schema.sql ya incluye
-- estos cambios, así que una base creada desde cero no necesita esta
-- migración.
--
-- Por qué existe:
--   El RF4 pide que el personal del gimnasio escanee el QR de la reserva
--   en la entrada, que el código sirva una sola vez y solo durante su
--   franja, y que se pueda validar a mano por número de documento cuando
--   la persona no puede mostrar el código (CU04, flujo 3a).
--
--   La función registrar_asistencia(qr) del esquema original tenía un
--   hueco: la podía llamar cualquiera que iniciara sesión, así que un
--   usuario podía registrar su propio ingreso sin pasar por la entrada.
--
-- Qué cambia:
--   1. asistencias.metodo: 'qr' o 'manual', para que el RF12 y la
--      bitácora sepan cómo se validó cada ingreso.
--   2. Se borra registrar_asistencia(qr) y la reemplazan tres funciones
--      que solo puede usar el personal (instructor o administrador):
--        validar_ingreso(codigo)          escaneo del QR (CU04, 3-5)
--        buscar_reservas_de_hoy(documento) búsqueda manual (CU04, 3a)
--        validar_ingreso_manual(reserva)  validación manual (CU04, 3a)
--      Responden con un resultado en texto, igual que reservar_cupos() y
--      cancelar_reserva().
--
-- Resultados de la validación:
--   valido        se registró el ingreso ahora
--   ya_validado   el código ya se había usado (CU04, 4a)
--   temprano      faltan más de 15 minutos para la franja (CU04, 4b)
--   vencido       la franja ya terminó (CU04, 4b)
--   cancelada     la reserva fue cancelada (CU04, 4c)
--   inexistente   el código no corresponde a ninguna reserva (CU04, 4c)
--
-- Va después de la 014. Se puede correr más de una vez.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Cómo se validó cada ingreso
-- ---------------------------------------------------------------------

alter table public.asistencias
  add column if not exists metodo text not null default 'qr';

alter table public.asistencias
  drop constraint if exists asistencias_metodo_valido;
alter table public.asistencias
  add constraint asistencias_metodo_valido check (metodo in ('qr', 'manual'));

comment on column public.asistencias.metodo is
  'RF4: qr si el personal escaneó el código; manual si buscó la reserva por documento (CU04, 3a).';


-- ---------------------------------------------------------------------
-- 2. Quién es personal del gimnasio
-- ---------------------------------------------------------------------

create or replace function public.es_personal()
returns boolean
language sql
stable
as $$
  select coalesce(public.rol_actual() in ('instructor', 'administrador'), false);
$$;

comment on function public.es_personal() is
  'true si quien llama es instructor o administrador: puede validar ingresos (RF4).';


-- ---------------------------------------------------------------------
-- 3. La validación, en un solo sitio
--    No se le da permiso a nadie: la usan las dos funciones públicas de
--    abajo, que primero comprueban que quien llama sea personal.
-- ---------------------------------------------------------------------

drop function if exists public.registrar_asistencia(uuid);

create or replace function public.validar_reserva(
  p_reserva_id  bigint,
  p_metodo      text
)
returns table (
  resultado      text,
  reserva        jsonb,
  persona        text,
  documento      text,
  hora_inicio    time,
  hora_fin       time,
  zona           text,
  registrada_en  timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  r        public.reservas;
  f        public.franjas;
  a        public.asistencias;
  p        public.perfiles;
  z        public.zonas;
  -- La base corre en UTC y las franjas están en hora de Bucaramanga.
  ahora    timestamp := timezone('America/Bogota', now());
  res      text;
begin
  -- for update: si dos porteros escanean el mismo código a la vez, el
  -- segundo espera y luego ve el ingreso del primero.
  select * into r from public.reservas where id = p_reserva_id for update;
  if not found then
    return query select 'inexistente'::text, null::jsonb, null::text,
      null::text, null::time, null::time, null::text, null::timestamptz;
    return;
  end if;

  select * into f from public.franjas where id = r.franja_id;
  select * into p from public.perfiles where id = r.perfil_id;
  select * into z from public.zonas where id = r.zona_id;
  select * into a from public.asistencias where reserva_id = r.id;

  if a.id is not null then
    res := 'ya_validado';
  elsif r.estado = 'cancelada' then
    res := 'cancelada';
  elsif ahora < (f.fecha + f.hora_inicio) - interval '15 minutes' then
    res := 'temprano';
  elsif ahora > (f.fecha + f.hora_fin) then
    res := 'vencido';
  else
    insert into public.asistencias (reserva_id, registrada_por, metodo)
    values (r.id, auth.uid(), p_metodo)
    returning * into a;

    update public.reservas set estado = 'asistida' where id = r.id
    returning * into r;

    res := 'valido';
  end if;

  return query select
    res,
    to_jsonb(r),
    p.nombre || ' ' || p.apellido,
    p.documento,
    f.hora_inicio,
    f.hora_fin,
    z.nombre,
    a.registrada_en;
end;
$$;

revoke all on function public.validar_reserva(bigint, text) from public, anon, authenticated;


-- ---------------------------------------------------------------------
-- 4. Escanear el QR (CU04, flujo principal)
-- ---------------------------------------------------------------------

create or replace function public.validar_ingreso(p_codigo text)
returns table (
  resultado      text,
  reserva        jsonb,
  persona        text,
  documento      text,
  hora_inicio    time,
  hora_fin       time,
  zona           text,
  registrada_en  timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_codigo   uuid;
  v_reserva  bigint;
begin
  if not public.es_personal() then
    raise exception 'Solo el personal del gimnasio puede validar ingresos.'
      using errcode = '42501';
  end if;

  -- Un QR que no es un código de UFIT (otra app, un enlace) no es un
  -- error del sistema: es un código inexistente.
  begin
    v_codigo := btrim(p_codigo)::uuid;
  exception when invalid_text_representation then
    v_codigo := null;
  end;

  select id into v_reserva from public.reservas where codigo_qr = v_codigo;

  return query select * from public.validar_reserva(v_reserva, 'qr');
end;
$$;

comment on function public.validar_ingreso(text) is
  'RF4: valida el código del QR de una reserva y registra el ingreso. Solo instructor o administrador.';

revoke all on function public.validar_ingreso(text) from public, anon;
grant execute on function public.validar_ingreso(text) to authenticated;


-- ---------------------------------------------------------------------
-- 5. Validación manual por documento (CU04, flujo 3a)
-- ---------------------------------------------------------------------

create or replace function public.buscar_reservas_de_hoy(p_documento text)
returns table (
  reserva_id    bigint,
  persona       text,
  documento     text,
  hora_inicio   time,
  hora_fin      time,
  zona          text,
  estado        public.estado_reserva,
  validada      boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.es_personal() then
    raise exception 'Solo el personal del gimnasio puede validar ingresos.'
      using errcode = '42501';
  end if;

  return query
    select r.id,
           p.nombre || ' ' || p.apellido,
           p.documento,
           f.hora_inicio,
           f.hora_fin,
           z.nombre,
           r.estado,
           exists (select 1 from public.asistencias a where a.reserva_id = r.id)
      from public.perfiles p
      join public.reservas r on r.perfil_id = p.id
      join public.franjas f on f.id = r.franja_id
      join public.zonas z on z.id = r.zona_id
     where p.documento = btrim(p_documento)
       and r.fecha = public.hoy_local()
       and r.estado <> 'cancelada'
     order by f.hora_inicio;
end;
$$;

comment on function public.buscar_reservas_de_hoy(text) is
  'RF4, CU04 3a: las reservas de hoy de una persona, buscada por documento. Solo instructor o administrador.';

revoke all on function public.buscar_reservas_de_hoy(text) from public, anon;
grant execute on function public.buscar_reservas_de_hoy(text) to authenticated;

create or replace function public.validar_ingreso_manual(p_reserva_id bigint)
returns table (
  resultado      text,
  reserva        jsonb,
  persona        text,
  documento      text,
  hora_inicio    time,
  hora_fin       time,
  zona           text,
  registrada_en  timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.es_personal() then
    raise exception 'Solo el personal del gimnasio puede validar ingresos.'
      using errcode = '42501';
  end if;

  return query select * from public.validar_reserva(p_reserva_id, 'manual');
end;
$$;

comment on function public.validar_ingreso_manual(bigint) is
  'RF4, CU04 3a: valida el ingreso de una reserva buscada por documento. Mismas reglas que el QR.';

revoke all on function public.validar_ingreso_manual(bigint) from public, anon;
grant execute on function public.validar_ingreso_manual(bigint) to authenticated;


-- ---------------------------------------------------------------------
-- 6. Asistencias: nadie las escribe directo
--    Solo las funciones de arriba registran ingresos.
-- ---------------------------------------------------------------------

revoke insert, update, delete on public.asistencias from anon, authenticated;

comment on column public.reservas.codigo_qr is
  'Se genera al crear la reserva y es lo que codifica el QR del RF4. Vence al terminar la franja: la validación la hace validar_ingreso() (sección 13).';
