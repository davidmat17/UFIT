-- =====================================================================
-- Migración 009 — RF2: horario del gimnasio, lunes a viernes de 6 a. m. a 8 p. m.
-- Proyecto de Ingeniería de Software 1, Grupo 8, UIS
--
-- Se corre UNA vez en el SQL Editor de Supabase, sobre la base que ya
-- tiene schema.sql y las migraciones 001 a 008. schema.sql ya incluye
-- este cambio, así que una base creada desde cero no la necesita.
--
-- Qué cambia:
--   1. generar_franjas() ya no crea franjas los sábados ni los domingos,
--      y la última franja del día es de 7 a 8 p. m. (antes llegaba a las
--      9 p. m.).
--   2. Borra las franjas que ya existían fuera de ese horario: fines de
--      semana y la de 8 a 9 p. m. Si alguna tuviera reservas, no se
--      borra (dejaría huecos en el historial): se cierra.
--   3. Agrega dos restricciones, franjas_solo_lunes_a_viernes y
--      franjas_horario_de_servicio, para que la base rechace cualquier
--      franja nueva fuera del horario. Van con NOT VALID: se aplican a lo
--      nuevo y no revisan las filas cerradas del paso 2.
--
-- Se puede volver a correr sin problema.
-- =====================================================================

create or replace function public.generar_franjas(
  desde date,
  hasta date,
  hora_apertura time default '06:00',
  hora_cierre   time default '20:00'
)
returns integer
language plpgsql
as $$
declare
  dia    date;
  hora   time;
  creadas integer := 0;
begin
  dia := desde;
  while dia <= hasta loop
    -- isodow: 1 = lunes … 7 = domingo. El gimnasio no abre el fin de
    -- semana.
    if extract(isodow from dia) <= 5 then
      hora := hora_apertura;
      while hora < hora_cierre loop
        insert into public.franjas (fecha, hora_inicio, hora_fin)
        values (dia, hora, hora + interval '1 hour')
        on conflict (fecha, hora_inicio) do nothing;
        creadas := creadas + 1;
        hora := hora + interval '1 hour';
      end loop;
    end if;
    dia := dia + 1;
  end loop;
  return creadas;
end;
$$;

delete from public.franjas f
 where (extract(isodow from f.fecha) >= 6
        or f.hora_inicio < '06:00' or f.hora_fin > '20:00')
   and not exists (select 1 from public.reservas r where r.franja_id = f.id);

update public.franjas
   set estado = 'cerrada'
 where (extract(isodow from fecha) >= 6
        or hora_inicio < '06:00' or hora_fin > '20:00')
   and estado <> 'cerrada';

alter table public.franjas
  drop constraint if exists franjas_solo_lunes_a_viernes;
alter table public.franjas
  add constraint franjas_solo_lunes_a_viernes
  check (extract(isodow from fecha) <= 5) not valid;

alter table public.franjas
  drop constraint if exists franjas_horario_de_servicio;
alter table public.franjas
  add constraint franjas_horario_de_servicio
  check (hora_inicio >= '06:00' and hora_fin <= '20:00') not valid;
