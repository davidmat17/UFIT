-- =====================================================================
-- Migración 012 — RF3: cancelar una reserva con antelación mínima
-- Proyecto de Ingeniería de Software 1, Grupo 8, UIS
--
-- Se corre UNA vez en el SQL Editor de Supabase, sobre la base que ya
-- tiene schema.sql y las migraciones anteriores. schema.sql ya incluye
-- estos cambios, así que una base creada desde cero no necesita esta
-- migración.
--
-- Por qué existe:
--   El RF3 pide cancelar una reserva activa con una antelación mínima
--   (3 horas) que el administrador pueda configurar, y no dejar cancelar
--   una reserva cuyo ingreso ya se registró con el QR (CU03, 4a y 4b).
--   Hasta ahora la política reservas_cancelar_propia dejaba actualizar
--   CUALQUIER columna de la reserva propia, incluida franja_id: con eso
--   alguien podía moverse a una franja llena y saltarse el aforo.
--
-- Qué cambia:
--   1. Tabla nueva configuracion, de una sola fila, con las horas de
--      antelación para cancelar (3 por defecto). Todos los que inician
--      sesión la leen; solo el administrador la cambia (RF13).
--   2. Función nueva cancelar_reserva(reserva): verifica dueño, estado y
--      plazo, y cancela. Responde con un resultado en texto, igual que
--      reservar_cupos().
--   3. Se quita la política reservas_cancelar_propia y el permiso de
--      UPDATE: desde la app la única forma de cambiar una reserva es
--      cancelar_reserva().
--
-- El cupo queda libre en el mismo instante: vista_disponibilidad y
-- reservar_cupos() solo cuentan las reservas confirmadas o asistidas, y
-- el máximo de 3 por semana no cuenta las canceladas.
--
-- Va después de la 011. Se puede correr más de una vez.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Configuración del gimnasio
-- ---------------------------------------------------------------------

create table if not exists public.configuracion (
  -- Siempre true: impide que exista una segunda fila.
  id                         boolean primary key default true check (id),
  horas_antelacion_cancelar  smallint not null default 3
    check (horas_antelacion_cancelar between 0 and 24),
  actualizado_en             timestamptz not null default now()
);

comment on table public.configuracion is
  'Parámetros del gimnasio que cambia el administrador (RF13). Una sola fila.';
comment on column public.configuracion.horas_antelacion_cancelar is
  'RF3: una reserva se puede cancelar hasta esta cantidad de horas antes de que empiece la franja.';

insert into public.configuracion (id) values (true)
on conflict (id) do nothing;

drop trigger if exists configuracion_actualizado_en on public.configuracion;
create trigger configuracion_actualizado_en
  before update on public.configuracion
  for each row execute function public.tocar_actualizado_en();

alter table public.configuracion enable row level security;

drop policy if exists configuracion_lectura on public.configuracion;
create policy configuracion_lectura on public.configuracion
  for select to authenticated using (true);

drop policy if exists configuracion_admin on public.configuracion;
create policy configuracion_admin on public.configuracion
  for update using (public.es_administrador()) with check (public.es_administrador());

-- La fila no se crea ni se borra desde la app.
revoke insert, delete on public.configuracion from anon, authenticated;
revoke all on public.configuracion from anon;


-- ---------------------------------------------------------------------
-- 2. cancelar_reserva()
-- ---------------------------------------------------------------------

-- Qué devuelve (una sola fila):
--
--   resultado        significado
--   ---------------  ---------------------------------------------------
--   cancelada        se canceló ahora; el cupo quedó libre
--   ya_cancelada     ya estaba cancelada, por ejemplo desde otro
--                    dispositivo (CU03, 4c). Reintentar es seguro.
--   ya_asistida      el ingreso ya se registró con el QR (CU03, 4b)
--   fuera_de_plazo   faltan menos horas de las permitidas para que
--                    empiece la franja, o ya pasó (CU03, 4a)
--   inexistente      no existe o no es de quien la pide
--
-- La columna reserva trae la reserva tal como quedó (null si es
-- inexistente) y horas_antelacion, el plazo vigente, para que la app
-- explique la restricción con el número correcto.
--
-- Sin sesión falla con un mensaje que la app muestra tal cual.
create or replace function public.cancelar_reserva(p_reserva_id bigint)
returns table (
  resultado         text,
  reserva           jsonb,
  horas_antelacion  smallint
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_perfil   uuid := auth.uid();
  -- La base corre en UTC y las franjas están en hora de Bucaramanga.
  v_ahora    timestamp := timezone('America/Bogota', now());
  v_reserva  public.reservas;
  v_franja   public.franjas;
begin
  if v_perfil is null then
    raise exception 'Inicia sesión para cancelar una reserva';
  end if;

  select c.horas_antelacion_cancelar into horas_antelacion
    from public.configuracion c;
  horas_antelacion := coalesce(horas_antelacion, 3);

  -- El mismo bloqueo por persona que reservar_cupos(): cancelar y
  -- reservar a la vez desde dos celulares se atienden en orden.
  perform pg_advisory_xact_lock(hashtext(v_perfil::text));

  select * into v_reserva
    from public.reservas r
   where r.id = p_reserva_id
     and r.perfil_id = v_perfil
     for update;

  if not found then
    resultado := 'inexistente';
    reserva   := null;
    return next;
    return;
  end if;

  select * into v_franja from public.franjas f where f.id = v_reserva.franja_id;

  if v_reserva.estado = 'cancelada' then
    resultado := 'ya_cancelada';

  elsif v_reserva.estado = 'asistida'
        or exists (select 1 from public.asistencias a where a.reserva_id = v_reserva.id) then
    resultado := 'ya_asistida';

  elsif v_reserva.estado <> 'confirmada'
        or v_ahora > (v_franja.fecha + v_franja.hora_inicio)
                     - make_interval(hours => horas_antelacion) then
    resultado := 'fuera_de_plazo';

  else
    update public.reservas r
       set estado = 'cancelada',
           cancelada_en = now()
     where r.id = v_reserva.id
    returning * into v_reserva;

    resultado := 'cancelada';
  end if;

  reserva := to_jsonb(v_reserva);
  return next;
end;
$$;

comment on function public.cancelar_reserva(bigint) is
  'Cancela una reserva propia si faltan al menos las horas de configuracion.horas_antelacion_cancelar para la franja. Libera el cupo. Es la única vía para cambiar una reserva desde la app (RF3).';

-- Solo quien inició sesión. Sin esto, PostgREST la expone también a anon.
revoke all on function public.cancelar_reserva(bigint) from public, anon;
grant execute on function public.cancelar_reserva(bigint) to authenticated;


-- ---------------------------------------------------------------------
-- 3. Cerrar la puerta de atrás: ya no se actualiza directo en reservas
-- ---------------------------------------------------------------------

drop policy if exists reservas_cancelar_propia on public.reservas;
revoke update on public.reservas from anon, authenticated;
