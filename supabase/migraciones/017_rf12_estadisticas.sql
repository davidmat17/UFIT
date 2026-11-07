-- =====================================================================
-- Migración 017 — RF12: estadísticas de ocupación y uso
-- Proyecto de Ingeniería de Software 1, Grupo 8, UIS
--
-- Se corre UNA vez en el SQL Editor de Supabase, sobre la base que ya
-- tiene schema.sql y las migraciones anteriores. schema.sql ya incluye
-- estos cambios, así que una base creada desde cero no necesita esta
-- migración.
--
-- Por qué existe:
--   El RF12 pide que el administrador vea la ocupación del gimnasio, la
--   asistencia efectiva frente a las reservas y el uso por zona, filtrado
--   por fechas, franja horaria o zona (CU12). Calcularlo en la base, y no
--   en el celular, evita bajar miles de reservas para contar.
--
-- Qué cambia:
--   Función nueva estadisticas_uso(desde, hasta, zona, hora), que
--   devuelve un JSON con el resumen, la ocupación por hora, por día de la
--   semana y por zona, y el estado del inventario de máquinas.
--
--   Si la llama alguien que no es administrador, no devuelve nada y deja
--   el intento en la bitácora (CU12, 1a). Por eso no lanza un error: un
--   error desharía la línea de la bitácora.
--
-- Cómo se cuenta cada reserva:
--   asistida     tiene ingreso registrado (RF4)
--   no_asistida  confirmada y su franja ya terminó, sin ingreso
--   pendiente    confirmada y su franja no ha terminado
--   cancelada    la canceló la persona (RF3)
--   Ocupación de una franja = reservas vivas / cupo de la franja (75).
--
-- Va después de la 016. Se puede correr más de una vez.
-- =====================================================================

create or replace function public.estadisticas_uso(
  p_desde    date,
  p_hasta    date,
  p_zona_id  smallint default null,
  p_hora     time default null
)
returns jsonb
language plpgsql
-- Volátil (no stable) porque puede escribir en la bitácora.
security definer
set search_path = public
as $$
declare
  ahora      timestamp := timezone('America/Bogota', now());
  resultado  jsonb;
begin
  if not public.es_administrador() then
    perform public.anotar_acceso_denegado('estadisticas_uso');
    return jsonb_build_object('permitido', false);
  end if;

  if p_desde is null or p_hasta is null or p_hasta < p_desde then
    raise exception 'La fecha inicial no puede ser posterior a la final.';
  end if;
  if p_hasta - p_desde > 366 then
    raise exception 'Consulta como máximo un año a la vez.';
  end if;

  with franjas_rango as (
    select f.*
      from public.franjas f
     where f.fecha between p_desde and p_hasta
       and (p_hora is null or f.hora_inicio = p_hora)
  ),
  clasificadas as (
    select r.id,
           r.zona_id,
           f.id as franja_id,
           f.fecha,
           f.hora_inicio,
           case
             when r.estado = 'cancelada' then 'cancelada'
             when r.estado = 'asistida'
               or exists (select 1 from public.asistencias a where a.reserva_id = r.id)
               then 'asistida'
             when r.estado = 'no_asistida' or (f.fecha + f.hora_fin) <= ahora
               then 'no_asistida'
             else 'pendiente'
           end as clase
      from public.reservas r
      join franjas_rango f on f.id = r.franja_id
     where (p_zona_id is null or r.zona_id = p_zona_id)
  ),
  por_franja as (
    select f.id,
           f.fecha,
           f.hora_inicio,
           f.cupo_total,
           count(c.id) filter (where c.clase <> 'cancelada') as vivas,
           count(c.id) filter (where c.clase = 'asistida') as asistidas
      from franjas_rango f
      left join clasificadas c on c.franja_id = f.id
     group by f.id, f.fecha, f.hora_inicio, f.cupo_total
  )
  select jsonb_build_object(
    'permitido', true,
    'desde', p_desde,
    'hasta', p_hasta,
    'resumen', (
      select jsonb_build_object(
        'franjas', (select count(*) from por_franja),
        'reservas', count(*),
        'asistidas', count(*) filter (where clase = 'asistida'),
        'no_asistidas', count(*) filter (where clase = 'no_asistida'),
        'pendientes', count(*) filter (where clase = 'pendiente'),
        'canceladas', count(*) filter (where clase = 'cancelada'),
        'ocupacion_promedio', (
          select round(avg(vivas * 100.0 / cupo_total), 1) from por_franja)
      )
      from clasificadas
    ),
    'por_hora', coalesce((
      select jsonb_agg(h order by h.hora)
        from (
          select to_char(hora_inicio, 'HH24:MI') as hora,
                 count(*) as franjas,
                 sum(vivas) as reservas,
                 sum(asistidas) as asistidas,
                 round(avg(vivas * 100.0 / cupo_total), 1) as ocupacion
            from por_franja
           group by hora_inicio
        ) h
    ), '[]'::jsonb),
    'por_dia', coalesce((
      select jsonb_agg(d order by d.dia)
        from (
          select extract(isodow from fecha)::int as dia,
                 count(*) as franjas,
                 sum(vivas) as reservas,
                 sum(asistidas) as asistidas,
                 round(avg(vivas * 100.0 / cupo_total), 1) as ocupacion
            from por_franja
           group by 1
        ) d
    ), '[]'::jsonb),
    'por_zona', coalesce((
      select jsonb_agg(z order by z.zona_id)
        from (
          select zo.id as zona_id,
                 zo.nombre as zona,
                 count(c.id) filter (where c.clase <> 'cancelada') as reservas,
                 count(c.id) filter (where c.clase = 'asistida') as asistidas,
                 count(c.id) filter (where c.clase = 'no_asistida') as no_asistidas,
                 count(c.id) filter (where c.clase = 'cancelada') as canceladas
            from public.zonas zo
            left join clasificadas c on c.zona_id = zo.id
           where p_zona_id is null or zo.id = p_zona_id
           group by zo.id, zo.nombre
        ) z
    ), '[]'::jsonb),
    'maquinas', coalesce((
      select jsonb_agg(m order by m.zona_id)
        from (
          select zo.id as zona_id,
                 zo.nombre as zona,
                 coalesce(sum(ma.cantidad) filter (where ma.estado = 'disponible'), 0) as disponibles,
                 coalesce(sum(ma.cantidad) filter (where ma.estado <> 'disponible'), 0) as fuera_de_servicio
            from public.zonas zo
            left join public.maquinas ma on ma.zona_id = zo.id
           where p_zona_id is null or zo.id = p_zona_id
           group by zo.id, zo.nombre
        ) m
    ), '[]'::jsonb)
  ) into resultado;

  return resultado;
end;
$$;

comment on function public.estadisticas_uso(date, date, smallint, time) is
  'RF12: ocupación, asistencia efectiva y uso por zona en un rango. Solo el administrador; los demás intentos quedan en la bitácora.';

-- Deja en la bitácora un intento de entrar donde no se tiene permiso.
create or replace function public.anotar_acceso_denegado(p_recurso text)
returns void
language sql
volatile
security definer
set search_path = public
as $$
  select public.anotar_en_bitacora('acceso_denegado', p_recurso, auth.uid()::text, null);
$$;

revoke all on function public.anotar_acceso_denegado(text) from public, anon, authenticated;

revoke all on function public.estadisticas_uso(date, date, smallint, time) from public, anon;
grant execute on function public.estadisticas_uso(date, date, smallint, time) to authenticated;
