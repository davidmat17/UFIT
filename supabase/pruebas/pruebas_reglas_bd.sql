-- =====================================================================
-- Pruebas de las reglas de la base de datos de UFIT
-- Proyecto de Ingeniería de Software 1, Grupo 8, UIS
--
-- Comprueba, una por una, las reglas del gimnasio que hace cumplir la
-- base (funciones, restricciones y políticas de seguridad). Cada caso se
-- ejecuta con el rol y la sesión de una persona concreta, como lo haría
-- la aplicación, y su resultado queda en una tabla.
--
-- Todo corre dentro de una transacción que al final se deshace
-- (ROLLBACK): no deja datos de prueba en la base.
--
-- Cómo correrlo en local (PostgreSQL 16):
--   1. supabase/pruebas/simulacion_auth.sql   (esquema auth de Supabase)
--   2. supabase/schema.sql
--   3. este archivo
-- =====================================================================

begin;

-- Para poder probar a cualquier hora y cualquier día (incluido el fin de
-- semana), dentro de esta transacción se quitan las dos restricciones de
-- horario de las franjas. El ROLLBACK final las devuelve.
alter table public.franjas drop constraint franjas_solo_lunes_a_viernes;
alter table public.franjas drop constraint franjas_horario_de_servicio;

create temp table resultados (
  n        serial,
  rf       text,
  caso     text,
  esperado text,
  obtenido text
);
grant all on resultados to authenticated, anon;
grant all on sequence resultados_n_seq to authenticated, anon;

-- Anota un caso.
create function pg_temp.probar(p_rf text, p_caso text, p_esperado text, p_obtenido text)
returns void language sql as $$
  insert into resultados (rf, caso, esperado, obtenido)
  values (p_rf, p_caso, p_esperado, coalesce(p_obtenido, '(nulo)'));
$$;

-- Ejecuta una sentencia y devuelve 'sin error' o el código SQLSTATE con
-- el mensaje, para los casos en que lo esperado es que la base rechace.
create function pg_temp.error_de(p_sql text)
returns text language plpgsql as $$
begin
  execute p_sql;
  return 'sin error';
exception when others then
  return sqlstate || ': ' || sqlerrm;
end;
$$;

-- Ejecuta una sentencia de modificación y dice cuántas filas cambió.
create function pg_temp.filas(p_sql text)
returns text language plpgsql as $$
declare n integer;
begin
  execute p_sql;
  get diagnostics n = row_count;
  return n || ' filas';
end;
$$;

grant execute on function pg_temp.probar(text, text, text, text) to authenticated, anon;
grant execute on function pg_temp.filas(text) to authenticated, anon;
grant execute on function pg_temp.error_de(text) to authenticated, anon;

-- ---------------------------------------------------------------------
-- Datos de prueba
-- ---------------------------------------------------------------------

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'admin.prueba@uis.edu.co'),
  ('00000000-0000-0000-0000-0000000000b1', 'instructor.prueba@uis.edu.co'),
  ('00000000-0000-0000-0000-0000000000c1', 'ana.prueba@correo.uis.edu.co'),
  ('00000000-0000-0000-0000-0000000000c2', 'beto.prueba@correo.uis.edu.co');

insert into public.perfiles (id, nombre, apellido, documento, correo, rol) values
  ('00000000-0000-0000-0000-0000000000a1', 'Ada', 'Admin', '90000001', 'admin.prueba@uis.edu.co', 'administrador'),
  ('00000000-0000-0000-0000-0000000000b1', 'Iván', 'Instructor', '90000002', 'instructor.prueba@uis.edu.co', 'instructor'),
  ('00000000-0000-0000-0000-0000000000c1', 'Ana', 'Usuaria', '90000003', 'ana.prueba@correo.uis.edu.co', 'usuario'),
  ('00000000-0000-0000-0000-0000000000c2', 'Beto', 'Usuario', '90000004', 'beto.prueba@correo.uis.edu.co', 'usuario');

-- Franjas alrededor de "ahora" (hora de Bucaramanga):
--   actual   la que está en curso
--   pasada   hace tres horas
--   pronto   empieza en una hora (dentro del plazo de 3 h para cancelar)
--   lejos    dentro de 5 días
--   semana   cuatro días de dentro de dos semanas, para el máximo de 3
create temp table h as
  select date_trunc('hour', timezone('America/Bogota', now())) as ahora;
grant select on h to authenticated, anon;

insert into public.franjas (fecha, hora_inicio, hora_fin)
select (ahora + d)::date, (ahora + d)::time, (ahora + d + interval '1 hour')::time
  from h, (values (interval '0 hour'), (interval '-3 hour'), (interval '1 hour'),
                  (interval '5 day')) v(d)
on conflict do nothing;

insert into public.franjas (fecha, hora_inicio, hora_fin)
select (date_trunc('week', ahora) + interval '14 day' + (i || ' day')::interval)::date,
       '09:00', '10:00'
  from h, generate_series(0, 3) i
on conflict do nothing;

create temp view f as
  select
    (select id from public.franjas, h where fecha = ahora::date and hora_inicio = ahora::time) as actual,
    (select id from public.franjas, h where fecha = (ahora - interval '3 hour')::date
                                        and hora_inicio = (ahora - interval '3 hour')::time) as pasada,
    (select id from public.franjas, h where fecha = (ahora + interval '1 hour')::date
                                        and hora_inicio = (ahora + interval '1 hour')::time) as pronto,
    (select id from public.franjas, h where fecha = (ahora + interval '5 day')::date
                                        and hora_inicio = ahora::time) as lejos;
grant select on f to authenticated, anon;

create temp view semana as
  select id, row_number() over (order by fecha) as i
    from public.franjas, h
   where fecha between (date_trunc('week', ahora) + interval '14 day')::date
                   and (date_trunc('week', ahora) + interval '17 day')::date
     and hora_inicio = '09:00';
grant select on semana to authenticated, anon;

set local role authenticated;

-- =====================================================================
-- RF2 — Reservas
-- =====================================================================
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000c1';

select pg_temp.probar('RF2', 'Reservar una franja futura con cupo', 'creada',
  (select resultado from reservar_cupos(array[(select lejos from f)], 1::smallint)));

select pg_temp.probar('RF2', 'Repetir la misma reserva no la duplica', 'ya_reservada',
  (select resultado from reservar_cupos(array[(select lejos from f)], 1::smallint)));

select pg_temp.probar('RF2', 'Segunda reserva el mismo día', 'otra_reserva_ese_dia',
  (select resultado from reservar_cupos(array[(select id from public.franjas, h
     where fecha = (ahora + interval '5 day')::date and id <> (select lejos from f)
     limit 1)], 1::smallint)));

select pg_temp.probar('RF2', 'Reservar una franja que ya terminó', 'franja_pasada',
  (select resultado from reservar_cupos(array[(select pasada from f)], 1::smallint)));

select pg_temp.probar('RF2', 'Cuarta reserva en la misma semana', 'creada, creada, creada, limite_semanal',
  (select string_agg(resultado, ', ' order by franja)
     from reservar_cupos((select array_agg(id order by i) from semana), 2::smallint)));

select pg_temp.probar('RF2', 'Reservar en una zona que no existe', 'P0001: La zona elegida no está disponible',
  pg_temp.error_de('select * from reservar_cupos(array[1::bigint], 99::smallint)'));

select pg_temp.probar('RF2', 'Insertar una reserva directo en la tabla', '42501',
  left(pg_temp.error_de(format(
    'insert into reservas (perfil_id, franja_id, fecha, zona_id) values (%L, %s, current_date, 1)',
    '00000000-0000-0000-0000-0000000000c1', (select lejos from f))), 5));

-- Aforo: se llena la franja "actual" hasta 75 con reservas de relleno.
reset role;
insert into auth.users (id, email)
select ('00000000-0000-0000-0001-' || lpad(i::text, 12, '0'))::uuid, 'relleno' || i || '@correo.uis.edu.co'
  from generate_series(1, 75) i;
insert into public.perfiles (id, nombre, apellido, documento, correo)
select ('00000000-0000-0000-0001-' || lpad(i::text, 12, '0'))::uuid, 'Relleno', i::text, '8' || lpad(i::text, 7, '0'),
       'relleno' || i || '@correo.uis.edu.co'
  from generate_series(1, 75) i;
insert into public.reservas (perfil_id, franja_id, fecha, zona_id)
select ('00000000-0000-0000-0001-' || lpad(i::text, 12, '0'))::uuid, f.actual, h.ahora::date, 1
  from generate_series(1, 75) i, f, h;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000c2';

select pg_temp.probar('RF2', 'Reservar una franja con los 75 cupos ocupados', 'sin_cupo',
  (select resultado from reservar_cupos(array[(select actual from f)], 1::smallint)));

select pg_temp.probar('RF2', 'La vista de disponibilidad cuenta 75 ocupados', '75 / 0',
  (select cupos_ocupados || ' / ' || cupos_disponibles from vista_disponibilidad
    where franja_id = (select actual from f)));

-- =====================================================================
-- RF3 — Cancelar
-- =====================================================================
select pg_temp.probar('RF3', 'Reservar una franja que empieza en una hora', 'creada',
  (select resultado from reservar_cupos(array[(select pronto from f)], 1::smallint)));

select pg_temp.probar('RF3', 'Cancelar con menos de 3 horas de antelación', 'fuera_de_plazo',
  (select resultado from cancelar_reserva((select id from reservas
     where perfil_id = '00000000-0000-0000-0000-0000000000c2' and franja_id = (select pronto from f)))));

set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000c1';
select pg_temp.probar('RF3', 'Cancelar con antelación suficiente', 'cancelada',
  (select resultado from cancelar_reserva((select id from reservas
     where perfil_id = '00000000-0000-0000-0000-0000000000c1' and franja_id = (select lejos from f)))));

select pg_temp.probar('RF3', 'Cancelar dos veces la misma reserva', 'ya_cancelada',
  (select resultado from cancelar_reserva((select id from reservas
     where perfil_id = '00000000-0000-0000-0000-0000000000c1' and franja_id = (select lejos from f)))));

select pg_temp.probar('RF3', 'El cupo cancelado queda libre: se puede volver a reservar', 'creada',
  (select resultado from reservar_cupos(array[(select lejos from f)], 1::smallint)));

set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000c2';
select pg_temp.probar('RF3', 'Cancelar la reserva de otra persona', 'inexistente',
  (select resultado from cancelar_reserva((select id from reservas
     where perfil_id = '00000000-0000-0000-0000-0000000000c1' and franja_id = (select lejos from f)))));

set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';
select pg_temp.probar('RF3', 'El administrador cambia el plazo a 0 horas', '1 filas',
  pg_temp.filas('update configuracion set horas_antelacion_cancelar = 0'));
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000c2';
select pg_temp.probar('RF3', 'Con plazo 0 ya se puede cancelar la de dentro de una hora', 'cancelada',
  (select resultado from cancelar_reserva((select id from reservas
     where perfil_id = '00000000-0000-0000-0000-0000000000c2' and franja_id = (select pronto from f)))));
select pg_temp.probar('RF3', 'Un usuario no puede cambiar el plazo', '0 filas',
  pg_temp.filas('update configuracion set horas_antelacion_cancelar = 24'));

-- =====================================================================
-- RF4 — Ingreso con código QR
-- =====================================================================
reset role;
-- Ana tiene una reserva en la franja actual (se libera un cupo de relleno).
delete from reservas where franja_id = (select actual from f)
  and perfil_id = '00000000-0000-0000-0001-000000000001';
insert into reservas (perfil_id, franja_id, fecha, zona_id, codigo_qr)
select '00000000-0000-0000-0000-0000000000c1', actual, ahora::date, 1,
       '11111111-1111-1111-1111-111111111111'
  from f, h;
-- El instructor no puede leer las reservas de otros (RLS): el código de
-- la reserva futura se guarda antes, como si la persona lo mostrara.
create temp table codigo_futuro as
  select codigo_qr::text as codigo from reservas, f
   where perfil_id = '00000000-0000-0000-0000-0000000000c1'
     and franja_id = f.lejos and estado = 'confirmada';
grant select on codigo_futuro to authenticated;
set local role authenticated;

set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000c1';
select pg_temp.probar('RF4', 'La usuaria intenta validar su propio código', '42501',
  left(pg_temp.error_de($q$select * from validar_ingreso('11111111-1111-1111-1111-111111111111')$q$), 5));

set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000b1';
select pg_temp.probar('RF4', 'El instructor escanea un código de la franja actual', 'valido',
  (select resultado from validar_ingreso('11111111-1111-1111-1111-111111111111')));
select pg_temp.probar('RF4', 'Escanear otra vez el mismo código', 'ya_validado',
  (select resultado from validar_ingreso('11111111-1111-1111-1111-111111111111')));
select pg_temp.probar('RF4', 'Escanear un código que no es de UFIT', 'inexistente',
  (select resultado from validar_ingreso('https://ejemplo.com')));
select pg_temp.probar('RF4', 'Escanear el código de una reserva de dentro de 5 días', 'temprano',
  (select resultado from validar_ingreso((select codigo from codigo_futuro))));
select pg_temp.probar('RF4', 'Buscar por documento las reservas de hoy', '1 (validada)',
  (select count(*) || case when bool_and(validada) then ' (validada)' else '' end
     from buscar_reservas_de_hoy('90000003')));

set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000c1';
select pg_temp.probar('RF3', 'Cancelar una reserva con el ingreso ya registrado', 'ya_asistida',
  (select resultado from cancelar_reserva((select id from reservas
     where codigo_qr = '11111111-1111-1111-1111-111111111111'))));

-- =====================================================================
-- RF11 — Rutinas
-- =====================================================================
create temp table ej as
  select ejercicio_id, maquina_id from public.ejercicio_maquina order by 1, 2 limit 1;
reset role;
grant select on ej to authenticated;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000c2';
select pg_temp.probar('RF11', 'Día sábado (6) en un ejercicio', 'P0001',
  left(pg_temp.error_de(format($q$select * from crear_rutina('Otra',
     '[{"ejercicio_id": %s, "maquina_id": %s, "dias": [6], "repeticiones": 10}]', gen_random_uuid())$q$,
     (select ejercicio_id from ej), (select maquina_id from ej))), 5));

set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000c1';

select pg_temp.probar('RF11', 'Crear tres rutinas', 'creada, creada, creada',
  (select string_agg(r, ', ') from (
     select (select resultado from crear_rutina('Rutina ' || i,
        jsonb_build_array(jsonb_build_object('ejercicio_id', (select ejercicio_id from ej),
          'maquina_id', (select maquina_id from ej), 'dias', '[1,3]'::jsonb, 'repeticiones', 12)),
        gen_random_uuid())) as r
       from generate_series(1, 3) i) x));

select pg_temp.probar('RF11', 'Crear la cuarta rutina', 'maximo_rutinas',
  (select resultado from crear_rutina('Rutina 4',
     jsonb_build_array(jsonb_build_object('ejercicio_id', (select ejercicio_id from ej),
       'maquina_id', (select maquina_id from ej), 'dias', '[1]'::jsonb, 'minutos', 20)),
     gen_random_uuid())));

select pg_temp.probar('RF11', 'Escribir directo en la tabla de rutinas', '42501',
  left(pg_temp.error_de($q$insert into rutinas (perfil_id, nombre) values (auth.uid(), 'x')$q$), 5));

select pg_temp.probar('RF11', 'Eliminar una rutina propia', 'eliminada',
  (select eliminar_rutina((select min(id) from rutinas))));

-- =====================================================================
-- RF13 — Gestión de contenidos y bitácora
-- =====================================================================
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000c1';
select pg_temp.probar('RF13', 'Un usuario intenta publicar la normativa', '42501',
  left(pg_temp.error_de($q$select * from publicar_normativa('Hack', 'contenido de prueba', 2)$q$), 5));
select pg_temp.probar('RF13', 'Un usuario intenta editar una máquina', '0 filas',
  pg_temp.filas($q$update maquinas set nombre = 'x' where id = 1$q$));

set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';
select pg_temp.probar('RF13', 'Eliminar una máquina que usan rutinas', 'en_uso',
  (select resultado from eliminar_maquina((select maquina_id from ej))));
select pg_temp.probar('RF13', 'Eliminar un ejercicio que usan rutinas', 'en_uso',
  (select resultado from eliminar_ejercicio((select ejercicio_id from ej))));
select pg_temp.probar('RF13', 'Publicar con una versión base vieja', 'version_cambio',
  (select resultado from publicar_normativa('Normativa', 'Regla uno de prueba.', 1)));
select pg_temp.probar('RF13', 'Publicar sobre la versión vigente', 'publicada',
  (select resultado from publicar_normativa('Normativa', 'Regla uno de prueba.',
     (select max(version) from normativa))));
select pg_temp.probar('RF13', 'Solo queda una normativa vigente', '1',
  (select count(*)::text from normativa where vigente));
select pg_temp.probar('RF13', 'Asignar un turno a quien no es instructor', 'P0001',
  left(pg_temp.error_de($q$select asignar_turno('00000000-0000-0000-0000-0000000000c1', '{1}',
     '06:00', '08:00', current_date, current_date + 7)$q$), 5));
select pg_temp.probar('RF13', 'El administrador no se quita su propio rol', 'propia',
  actualizar_persona('00000000-0000-0000-0000-0000000000a1', 'usuario', true, null));
select pg_temp.probar('RF13', 'Los cambios quedan en la bitácora', 'sí',
  (select case when count(*) >= 2 then 'sí' else 'no' end from bitacora
    where perfil_id = '00000000-0000-0000-0000-0000000000a1'));

-- =====================================================================
-- RF12 — Estadísticas
-- =====================================================================
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000c2';
select pg_temp.probar('RF12', 'Un usuario pide las estadísticas', 'permitido = false',
  (select 'permitido = ' || (estadisticas_uso(current_date - 7, current_date + 7) ->> 'permitido')));
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000a1';
select pg_temp.probar('RF12', 'El intento queda en la bitácora', '1',
  (select count(*)::text from bitacora where accion = 'acceso_denegado'));
select pg_temp.probar('RF12', 'Asistencias contadas en el rango', '1',
  (select estadisticas_uso((select ahora::date from h), (select ahora::date from h)) -> 'resumen' ->> 'asistidas'));
select pg_temp.probar('RF12', 'Rango con la fecha final antes de la inicial', 'P0001',
  left(pg_temp.error_de($q$select estadisticas_uso(current_date, current_date - 1)$q$), 5));

-- =====================================================================
-- Seguridad entre cuentas (RLS)
-- =====================================================================
set local request.jwt.claim.sub = '00000000-0000-0000-0000-0000000000c2';
select pg_temp.probar('RNF9', 'Beto no ve las reservas de Ana', '0',
  (select count(*)::text from reservas where perfil_id = '00000000-0000-0000-0000-0000000000c1'));
select pg_temp.probar('RNF9', 'Beto no ve el perfil de Ana', '0',
  (select count(*)::text from perfiles where id = '00000000-0000-0000-0000-0000000000c1'));
select pg_temp.probar('RNF9', 'Beto no puede ponerse el rol de administrador', '42501',
  left(pg_temp.error_de($q$update perfiles set rol = 'administrador' where id = auth.uid()$q$), 5));
select pg_temp.probar('RNF9', 'Beto no lee la bitácora', '0',
  (select count(*)::text from bitacora));

reset role;
set local role anon;
set local request.jwt.claim.sub = '';
select pg_temp.probar('RF6', 'Sin sesión se lee la normativa vigente', '1',
  (select count(*)::text from normativa));
select pg_temp.probar('RNF9', 'Sin sesión no se ven reservas', '0',
  (select count(*)::text from reservas));

reset role;

-- =====================================================================
-- Resumen
-- =====================================================================
\pset format aligned
\pset tuples_only off
select n as "N°", rf as "Req.", caso as "Caso", esperado as "Esperado", obtenido as "Obtenido",
       case when obtenido = esperado or obtenido like esperado || '%' then 'PASA' else 'FALLA' end as "Resultado"
  from resultados order by n;

select count(*) filter (where obtenido = esperado or obtenido like esperado || '%') as pasan,
       count(*) filter (where not (obtenido = esperado or obtenido like esperado || '%')) as fallan,
       count(*) as total
  from resultados;

rollback;
