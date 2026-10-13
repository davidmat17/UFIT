-- =====================================================================
-- Migración 004 — RF5: fotos de las máquinas de prueba
-- Proyecto de Ingeniería de Software 1, Grupo 8, UIS
--
-- Se corre UNA vez en el SQL Editor de Supabase, sobre la base que ya
-- tiene schema.sql y las migraciones 001 a 003. schema.sql ya incluye
-- estos datos, así que una base creada desde cero no la necesita.
--
-- Qué cambia:
--   No toca la estructura de ninguna tabla. Solo llena la columna
--   maquinas.imagen_url de las nueve máquinas semilla con fotos de
--   Wikimedia Commons, todas con licencia libre. Los autores y las
--   licencias están en docs/creditos-imagenes.md. Son fotos de
--   referencia, no del gimnasio de la UIS: cuando exista el RF13, el
--   administrador las reemplaza por fotos reales.
--
-- Se puede volver a correr sin problema: solo actualiza por nombre.
-- =====================================================================

update public.maquinas set imagen_url =
  'https://upload.wikimedia.org/wikipedia/commons/thumb/6/62/Treadmill-gym.jpg/960px-Treadmill-gym.jpg'
where nombre = 'Trotadora';

update public.maquinas set imagen_url =
  'https://upload.wikimedia.org/wikipedia/commons/thumb/d/da/Elliptical_machine.jpg/960px-Elliptical_machine.jpg'
where nombre = 'Elíptica';

update public.maquinas set imagen_url =
  'https://upload.wikimedia.org/wikipedia/commons/1/14/Exercise_bike_-_29792771184_-_2016-10-19.jpg'
where nombre = 'Bicicleta estática';

update public.maquinas set imagen_url =
  'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8b/Weight_Bench_set.jpg/960px-Weight_Bench_set.jpg'
where nombre = 'Banco plano';

update public.maquinas set imagen_url =
  'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9f/Power_Rack.JPG/960px-Power_Rack.JPG'
where nombre = 'Rack de sentadilla';

update public.maquinas set imagen_url =
  'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d0/Marines%27_voices_echo%2C_prompt_new_gym_hours_150927-M-AI083-067.jpg/960px-Marines%27_voices_echo%2C_prompt_new_gym_hours_150927-M-AI083-067.jpg'
where nombre = 'Mancuernas';

update public.maquinas set imagen_url =
  'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9f/Leg_Press_Machine.jpg/960px-Leg_Press_Machine.jpg'
where nombre = 'Prensa de piernas';

update public.maquinas set imagen_url =
  'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2a/Diverging_Lat_Pulldown_Machine.jpg/960px-Diverging_Lat_Pulldown_Machine.jpg'
where nombre = 'Jalón al pecho';

update public.maquinas set imagen_url =
  'https://upload.wikimedia.org/wikipedia/commons/thumb/5/59/Leg_Extension.jpg/960px-Leg_Extension.jpg'
where nombre = 'Extensión de cuádriceps';
