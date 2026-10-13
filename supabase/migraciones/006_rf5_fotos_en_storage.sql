-- =====================================================================
-- Migración 006 — RF5: fotos de las máquinas en el Storage de Supabase
-- Proyecto de Ingeniería de Software 1, Grupo 8, UIS
--
-- Se corre UNA vez en el SQL Editor de Supabase, sobre la base que ya
-- tiene schema.sql y las migraciones 001 a 005. schema.sql ya incluye
-- estos datos, así que una base creada desde cero no la necesita.
--
-- ANTES de correrla, suba las 15 fotos de supabase/fotos-maquinas/ al
-- bucket público "maquinas" del Storage, con el mismo nombre de archivo.
-- Si falta alguna, esa máquina queda mostrando el ícono por defecto.
--
-- Qué cambia:
--   No toca la estructura de ninguna tabla. Cambia maquinas.imagen_url
--   de las 15 máquinas para que apunte al Storage del proyecto en lugar
--   de Wikimedia Commons. Las fotos son las mismas de las migraciones
--   004 y 005, redimensionadas a 600 px por el lado más largo y
--   comprimidas en JPEG (entre 28 y 81 KB cada una, unos 750 KB en
--   total), para que el catálogo cargue rápido también con datos
--   móviles. Créditos y licencias en docs/creditos-imagenes.md.
--
-- Se puede volver a correr sin problema: solo actualiza por nombre.
-- =====================================================================

update public.maquinas set imagen_url = 'https://ovhaqvhomiazygxzhwji.supabase.co/storage/v1/object/public/maquinas/trotadora.jpg'
where nombre = 'Trotadora';

update public.maquinas set imagen_url = 'https://ovhaqvhomiazygxzhwji.supabase.co/storage/v1/object/public/maquinas/eliptica.jpg'
where nombre = 'Elíptica';

update public.maquinas set imagen_url = 'https://ovhaqvhomiazygxzhwji.supabase.co/storage/v1/object/public/maquinas/bicicleta-estatica.jpg'
where nombre = 'Bicicleta estática';

update public.maquinas set imagen_url = 'https://ovhaqvhomiazygxzhwji.supabase.co/storage/v1/object/public/maquinas/banco-plano.jpg'
where nombre = 'Banco plano';

update public.maquinas set imagen_url = 'https://ovhaqvhomiazygxzhwji.supabase.co/storage/v1/object/public/maquinas/rack-de-sentadilla.jpg'
where nombre = 'Rack de sentadilla';

update public.maquinas set imagen_url = 'https://ovhaqvhomiazygxzhwji.supabase.co/storage/v1/object/public/maquinas/mancuernas.jpg'
where nombre = 'Mancuernas';

update public.maquinas set imagen_url = 'https://ovhaqvhomiazygxzhwji.supabase.co/storage/v1/object/public/maquinas/prensa-de-piernas.jpg'
where nombre = 'Prensa de piernas';

update public.maquinas set imagen_url = 'https://ovhaqvhomiazygxzhwji.supabase.co/storage/v1/object/public/maquinas/jalon-al-pecho.jpg'
where nombre = 'Jalón al pecho';

update public.maquinas set imagen_url = 'https://ovhaqvhomiazygxzhwji.supabase.co/storage/v1/object/public/maquinas/extension-de-cuadriceps.jpg'
where nombre = 'Extensión de cuádriceps';

update public.maquinas set imagen_url = 'https://ovhaqvhomiazygxzhwji.supabase.co/storage/v1/object/public/maquinas/bicicleta-reclinada.jpg'
where nombre = 'Bicicleta reclinada';

update public.maquinas set imagen_url = 'https://ovhaqvhomiazygxzhwji.supabase.co/storage/v1/object/public/maquinas/maquina-smith.jpg'
where nombre = 'Máquina Smith';

update public.maquinas set imagen_url = 'https://ovhaqvhomiazygxzhwji.supabase.co/storage/v1/object/public/maquinas/banco-inclinado.jpg'
where nombre = 'Banco inclinado';

update public.maquinas set imagen_url = 'https://ovhaqvhomiazygxzhwji.supabase.co/storage/v1/object/public/maquinas/banco-scott.jpg'
where nombre = 'Banco Scott';

update public.maquinas set imagen_url = 'https://ovhaqvhomiazygxzhwji.supabase.co/storage/v1/object/public/maquinas/maquina-de-aperturas.jpg'
where nombre = 'Máquina de aperturas';

update public.maquinas set imagen_url = 'https://ovhaqvhomiazygxzhwji.supabase.co/storage/v1/object/public/maquinas/sentadilla-hack.jpg'
where nombre = 'Sentadilla hack';
