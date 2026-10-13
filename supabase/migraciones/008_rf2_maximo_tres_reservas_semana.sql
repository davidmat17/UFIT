-- =====================================================================
-- Migración 008 — RF2: máximo 3 reservas por semana
-- Proyecto de Ingeniería de Software 1, Grupo 8, UIS
--
-- Se corre UNA vez en el SQL Editor de Supabase, sobre la base que ya
-- tiene schema.sql y las migraciones 001 a 007. schema.sql ya incluye
-- este cambio, así que una base creada desde cero no la necesita.
--
-- Qué cambia:
--   No toca la estructura de ninguna tabla. Agrega un disparador sobre
--   reservas que hace cumplir la regla 8 de la normativa (migración
--   007): una reserva por día, que ya existía, y ahora también máximo 3
--   por semana. La semana se cuenta de lunes a domingo (el gimnasio abre
--   de lunes a viernes, migración 009). La cuarta reserva de la semana
--   se rechaza con un mensaje que la app muestra tal cual.
--
-- Se puede volver a correr sin problema: reemplaza la función y el
-- disparador.
-- =====================================================================

-- Máximo 3 reservas por persona por semana, de lunes a domingo (regla 8
-- de la normativa). Cuentan todas menos las canceladas: una reserva a la
-- que no se asistió también gastó su cupo de la semana. Cancelar sí lo
-- devuelve.
create or replace function public.limitar_reservas_semana()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  lunes constant date := date_trunc('week', new.fecha)::date;
begin
  if new.estado = 'cancelada' then
    return new;
  end if;

  -- Mientras cuenta, bloquea las reservas de esta persona: así dos
  -- reservas enviadas al mismo tiempo no pasan las dos.
  perform pg_advisory_xact_lock(hashtext(new.perfil_id::text));

  if (select count(*)
        from public.reservas
       where perfil_id = new.perfil_id
         and estado <> 'cancelada'
         and fecha between lunes and lunes + 6
         and id is distinct from new.id) >= 3 then
    raise exception 'Ya tienes 3 reservas esta semana. La normativa del gimnasio permite máximo 3 por semana.';
  end if;
  return new;
end;
$$;

drop trigger if exists reservas_maximo_tres_por_semana on public.reservas;
create trigger reservas_maximo_tres_por_semana
  before insert or update of estado, fecha on public.reservas
  for each row execute function public.limitar_reservas_semana();
