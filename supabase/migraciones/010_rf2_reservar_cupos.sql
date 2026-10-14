-- =====================================================================
-- Migración 010 — RF2: reservar cupos con el aforo garantizado
-- Proyecto de Ingeniería de Software 1, Grupo 8, UIS
--
-- Se corre UNA vez en el SQL Editor de Supabase, sobre la base que ya
-- tiene schema.sql y las migraciones anteriores. schema.sql ya incluye
-- estos cambios, así que una base creada desde cero no necesita esta
-- migración.
--
-- Por qué existe:
--   Hasta ahora cualquiera con la clave pública de la app podía insertar
--   filas en reservas, y nada impedía pasarse de 75 personas en una
--   franja: la vista de disponibilidad solo cuenta, no frena. Revisar el
--   cupo en la app y luego insertar tampoco sirve: dos personas pueden
--   ver "queda 1 cupo" al mismo tiempo y reservar las dos.
--
-- Qué cambia (no se toca ninguna tabla ni columna):
--   1. Función nueva reservar_cupos(franjas, zona): reserva una o varias
--      franjas en UNA transacción. Bloquea cada franja mientras cuenta
--      y reserva, así que el cupo 76 es imposible. La reserva recurrente
--      del RF2 es esta misma función llamada con varias franjas.
--   2. Las reservas ya no se insertan directo desde la app: se quita la
--      política reservas_crear_propia y el permiso de INSERT.
--   3. La función respeta el máximo de 3 reservas por semana de la
--      migración 008: la franja que pase el límite responde
--      limite_semanal y las demás de la serie siguen su curso. El
--      disparador de la 008 se queda como respaldo.
--
-- Va después de la 009. Se puede correr más de una vez.
-- =====================================================================


-- Qué devuelve, una fila por franja pedida (sin repetidas):
--
--   resultado             significado
--   --------------------  -------------------------------------------
--   creada                reserva nueva
--   ya_reservada          ya tenías esa franja; es la misma reserva.
--                         Hace seguro reintentar si se cortó la red.
--   otra_reserva_ese_dia  ya tienes otra franja ese día (máx. una)
--   limite_semanal        ya tienes 3 reservas esa semana (regla 8 de
--                         la normativa, de lunes a domingo)
--   sin_cupo              la franja llegó al aforo
--   franja_cerrada        el administrador la cerró
--   franja_pasada         la franja ya terminó
--   franja_inexistente    el id no existe
--
-- Lo que no depende de una franja en concreto (sin sesión, cuenta
-- inactiva, zona inválida, lista vacía) no devuelve filas: falla con un
-- mensaje que la app muestra tal cual, como registrar_asistencia().
create or replace function public.reservar_cupos(
  p_franjas  bigint[],
  p_zona_id  smallint
)
returns table (
  franja     bigint,
  resultado  text,
  reserva    jsonb
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_perfil    uuid := auth.uid();
  -- La base corre en UTC y las franjas están en hora de Bucaramanga.
  v_ahora     timestamp := timezone('America/Bogota', now());
  v_ids       bigint[];
  v_id        bigint;
  v_franja    public.franjas;
  v_previa    public.reservas;
  v_nueva     public.reservas;
  v_ocupados  integer;
  v_lunes     date;
  v_semana    integer;
begin
  if v_perfil is null then
    raise exception 'Inicia sesión para reservar un cupo';
  end if;

  if not exists (
    select 1 from public.perfiles p where p.id = v_perfil and p.activo
  ) then
    raise exception 'Tu cuenta no está activa';
  end if;

  if not exists (
    select 1 from public.zonas z where z.id = p_zona_id and z.activa
  ) then
    raise exception 'La zona elegida no está disponible';
  end if;

  -- Sin repetidas y en orden. El orden importa: dos personas reservando
  -- varias franjas a la vez toman los bloqueos en la misma secuencia y
  -- no se traban una a la otra.
  select array_agg(distinct x order by x) into v_ids
    from unnest(p_franjas) as x
   where x is not null;

  if v_ids is null then
    raise exception 'Elige al menos una franja';
  end if;

  if array_length(v_ids, 1) > 60 then
    raise exception 'Se pueden reservar como máximo 60 franjas a la vez';
  end if;

  -- El mismo bloqueo por persona que toma el disparador de las 3 reservas
  -- por semana (limitar_reservas_semana): dos llamadas de la misma
  -- persona al tiempo cuentan una después de la otra.
  perform pg_advisory_xact_lock(hashtext(v_perfil::text));

  foreach v_id in array v_ids loop
    franja  := v_id;
    reserva := null;

    -- El bloqueo dura hasta el final de la transacción. Quien llegue
    -- después a la misma franja espera aquí, y cuando le toca el turno
    -- ya ve la reserva de quien lo precedió.
    select * into v_franja from public.franjas f where f.id = v_id for update;

    if not found then
      resultado := 'franja_inexistente';

    elsif v_franja.estado <> 'abierta' then
      resultado := 'franja_cerrada';

    elsif (v_franja.fecha + v_franja.hora_fin) <= v_ahora then
      resultado := 'franja_pasada';

    else
      select * into v_previa
        from public.reservas r
       where r.perfil_id = v_perfil
         and r.fecha = v_franja.fecha
         and r.estado in ('confirmada', 'asistida');

      if found then
        if v_previa.franja_id = v_franja.id then
          resultado := 'ya_reservada';
          reserva   := to_jsonb(v_previa);
        else
          resultado := 'otra_reserva_ese_dia';
        end if;

      else
        -- Máximo 3 por semana, contadas como el disparador: todas menos
        -- las canceladas, incluidas las que se acaban de crear en esta
        -- misma llamada. Se responde por franja, sin abortar, para que en
        -- una reserva recurrente las demás semanas sí queden reservadas.
        v_lunes := date_trunc('week', v_franja.fecha)::date;

        select count(*) into v_semana
          from public.reservas r
         where r.perfil_id = v_perfil
           and r.estado <> 'cancelada'
           and r.fecha between v_lunes and v_lunes + 6;

        if v_semana >= 3 then
          resultado := 'limite_semanal';
        else
          select count(*) into v_ocupados
            from public.reservas r
           where r.franja_id = v_franja.id
             and r.estado in ('confirmada', 'asistida');

          if v_ocupados >= v_franja.cupo_total then
            resultado := 'sin_cupo';
          else
            insert into public.reservas (perfil_id, franja_id, fecha, zona_id)
            values (v_perfil, v_franja.id, v_franja.fecha, p_zona_id)
            returning * into v_nueva;

            resultado := 'creada';
            reserva   := to_jsonb(v_nueva);
          end if;
        end if;
      end if;
    end if;

    return next;
  end loop;
end;
$$;

comment on function public.reservar_cupos(bigint[], smallint) is
  'Reserva una o varias franjas para quien tiene la sesión abierta, con el aforo garantizado. Una fila de resultado por franja. Es la única vía para crear reservas (RF2).';

-- Solo quien inició sesión. Sin esto, PostgREST la expone también a anon.
revoke all on function public.reservar_cupos(bigint[], smallint) from public, anon;
grant execute on function public.reservar_cupos(bigint[], smallint) to authenticated;


-- ---------------------------------------------------------------------
-- Cerrar la puerta de atrás: ya no se inserta directo en reservas.
-- ---------------------------------------------------------------------

drop policy if exists reservas_crear_propia on public.reservas;
revoke insert on public.reservas from anon, authenticated;

-- Pendiente para el RF3: la política reservas_cancelar_propia deja
-- actualizar CUALQUIER columna de la reserva propia, incluida franja_id.
-- Cancelar debería pasar por una función igual que esta (con la regla de
-- las 3 horas), y el UPDATE directo quitarse.
