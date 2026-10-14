-- =====================================================================
-- Datos de prueba — RF7: instructores ficticios y sus franjas
-- Proyecto de Ingeniería de Software 1, Grupo 8, UIS
--
-- NO es una migración: sirve para probar el RF7 mientras no exista la
-- pantalla de administración (RF13). Se corre en el SQL Editor de
-- Supabase DESPUÉS de la migración 011. Se puede correr más de una vez:
-- no duplica nada.
--
-- Crea 3 instructores que no son personas reales (no pueden iniciar
-- sesión: no tienen contraseña ni cuenta de Microsoft) y los asigna por
-- turnos a las franjas que ya existen desde hoy en adelante. Cada
-- instructor está a cargo de todo el gimnasio durante su turno:
--
--   Laura Gómez   · Entrenamiento funcional          · lunes a viernes de 6 a 12
--   Andrés Rojas  · Acondicionamiento cardiovascular · lunes a viernes de 2 a 6 p. m.
--   Camila Duarte · Técnica en máquinas guiadas      · martes y jueves de 6 a 8 p. m.
--
-- Quedan sin instructor, a propósito, las franjas de 12 a 2 p. m. todos
-- los días y las de 6 a 8 p. m. los lunes, miércoles y viernes: así se ve
-- el mensaje "Sin instructor asignado" (CU07, 4b).
--
-- Si después se generan más franjas, se vuelve a correr y asigna también
-- las nuevas. Al correrlo otra vez, las franjas de estos 3 instructores se
-- vuelven a repartir según los turnos de arriba.
--
-- Para BORRARLOS, al final del archivo hay un bloque comentado.
-- =====================================================================


-- 1. Cuentas mínimas en auth.users ------------------------------------
-- perfiles.id apunta a auth.users, así que cada instructor necesita una.

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data
)
values
  ('00000000-0000-0000-0000-000000000000', 'a7000000-0000-4000-8000-000000000001',
   'authenticated', 'authenticated', 'instructor1.prueba@uis.edu.co', '',
   now(), now(), now(), '{"provider":"prueba"}', '{}'),
  ('00000000-0000-0000-0000-000000000000', 'a7000000-0000-4000-8000-000000000002',
   'authenticated', 'authenticated', 'instructor2.prueba@uis.edu.co', '',
   now(), now(), now(), '{"provider":"prueba"}', '{}'),
  ('00000000-0000-0000-0000-000000000000', 'a7000000-0000-4000-8000-000000000003',
   'authenticated', 'authenticated', 'instructor3.prueba@uis.edu.co', '',
   now(), now(), now(), '{"provider":"prueba"}', '{}')
on conflict (id) do nothing;


-- 2. Perfiles con rol instructor --------------------------------------

insert into public.perfiles (id, nombre, apellido, documento, correo, rol, especialidad)
values
  ('a7000000-0000-4000-8000-000000000001', 'Laura', 'Gómez',
   'PRUEBA-INS-1', 'instructor1.prueba@uis.edu.co', 'instructor',
   'Entrenamiento funcional'),
  ('a7000000-0000-4000-8000-000000000002', 'Andrés', 'Rojas',
   'PRUEBA-INS-2', 'instructor2.prueba@uis.edu.co', 'instructor',
   'Acondicionamiento cardiovascular'),
  ('a7000000-0000-4000-8000-000000000003', 'Camila', 'Duarte',
   'PRUEBA-INS-3', 'instructor3.prueba@uis.edu.co', 'instructor',
   'Técnica en máquinas guiadas')
on conflict (id) do update
  set rol = excluded.rol,
      especialidad = excluded.especialidad,
      activo = true;


-- 3. Asignaciones por turno ------------------------------------------
-- isodow: 1 = lunes … 5 = viernes. Primero se quitan las asignaciones que
-- tuvieran estos 3 instructores, para repartirlas de nuevo. Una franja
-- que tenga otro instructor (uno real) no se toca.

delete from public.asignaciones_instructor
 where instructor_id in ('a7000000-0000-4000-8000-000000000001',
                         'a7000000-0000-4000-8000-000000000002',
                         'a7000000-0000-4000-8000-000000000003');

insert into public.asignaciones_instructor (instructor_id, franja_id)
select turno.instructor_id, f.id
  from public.franjas f
  join (values
    -- Laura: lunes a viernes de 6 a 12.
    ('a7000000-0000-4000-8000-000000000001'::uuid, array[1,2,3,4,5], time '06:00', time '12:00'),
    -- Andrés: lunes a viernes de 2 a 6 p. m.
    ('a7000000-0000-4000-8000-000000000002'::uuid, array[1,2,3,4,5], time '14:00', time '18:00'),
    -- Camila: martes y jueves de 6 a 8 p. m.
    ('a7000000-0000-4000-8000-000000000003'::uuid, array[2,4],       time '18:00', time '20:00')
  ) as turno (instructor_id, dias, desde, hasta)
    on extract(isodow from f.fecha)::int = any (turno.dias)
   and f.hora_inicio >= turno.desde
   and f.hora_inicio <  turno.hasta
 where f.fecha >= public.hoy_local()
on conflict (franja_id) do nothing;


-- Para ver cuántas quedaron:
--   select count(*) from public.asignaciones_instructor;


-- =====================================================================
-- BORRAR los instructores de prueba (y sus asignaciones). Selecciona
-- desde "delete" hasta el punto y coma y córrelo.
-- Borrar la cuenta borra en cascada el perfil y sus asignaciones.
-- =====================================================================
--
-- delete from auth.users
--  where id in ('a7000000-0000-4000-8000-000000000001',
--               'a7000000-0000-4000-8000-000000000002',
--               'a7000000-0000-4000-8000-000000000003');
