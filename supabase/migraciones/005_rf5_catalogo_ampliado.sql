-- =====================================================================
-- Migración 005 — RF5: catálogo ampliado de máquinas y ejercicios
-- Proyecto de Ingeniería de Software 1, Grupo 8, UIS
--
-- Se corre UNA vez en el SQL Editor de Supabase, sobre la base que ya
-- tiene schema.sql y las migraciones 001 a 004. schema.sql ya incluye
-- estos datos, así que una base creada desde cero no la necesita.
--
-- Qué cambia:
--   No toca la estructura de ninguna tabla. Solo agrega filas:
--   1. Ejercicios para las tres máquinas semilla que no tenían ninguno:
--      Elíptica, Bicicleta estática y Extensión de cuádriceps.
--   2. Seis máquinas nuevas que se ven en la foto del gimnasio de la
--      UIS (máquina Smith, banco inclinado, banco Scott, bicicleta
--      reclinada, máquina de aperturas y sentadilla hack), cada una con
--      sus ejercicios.
--   3. Fotos de referencia para las seis: cinco de Wikimedia Commons,
--      como en la migración 004, y la de la bicicleta reclinada desde
--      el Storage de Supabase.
--   Con esto el catálogo queda en 15 máquinas y 17 ejercicios. Las
--   cantidades son aproximadas; el administrador las corrige con el RF13.
--
-- Se puede volver a correr sin problema: todo se busca por nombre y los
-- insert ignoran lo que ya exista (on conflict do nothing).
-- =====================================================================

-- 1. Máquinas nuevas -------------------------------------------------

insert into public.maquinas (zona_id, nombre, descripcion, cantidad)
select z.id, v.nombre, v.descripcion, v.cantidad
from (values
  ('Cardiovascular', 'Bicicleta reclinada',
   'Bicicleta con espaldar, para pedalear sentado con la espalda apoyada.', 2),
  ('Fuerza', 'Máquina Smith',
   'Barra guiada sobre rieles verticales con seguros en cada altura.', 2),
  ('Fuerza', 'Banco inclinado',
   'Banco con respaldo inclinado y soporte para barra olímpica.', 1),
  ('Fuerza', 'Banco Scott',
   'Banco con atril para apoyar los brazos en el curl de bíceps.', 1),
  ('Musculación', 'Máquina de aperturas',
   'Máquina guiada de pecho con brazos que se cierran al frente.', 1),
  ('Musculación', 'Sentadilla hack',
   'Máquina de carga con discos para sentadilla con la espalda apoyada.', 1)
) as v (zona, nombre, descripcion, cantidad)
join public.zonas z on z.nombre = v.zona
on conflict (zona_id, nombre) do nothing;

-- 2. Ejercicios nuevos -----------------------------------------------

insert into public.ejercicios (nombre, grupo_muscular, descripcion, instrucciones) values
  ('Elíptica continua', 'Cardiovascular',
   'Movimiento elíptico a ritmo constante, sin impacto en las rodillas.',
   'Sube a la elíptica sujetándote de las barras fijas y apoya los pies completos en los pedales. Empieza con resistencia baja durante unos minutos para calentar. Sube la resistencia hasta un ritmo que puedas sostener mientras hablas con frases cortas. Mantén el tronco erguido y empuja y tira de las barras móviles para trabajar también los brazos.'),
  ('Pedaleo por intervalos', 'Cardiovascular',
   'Bloques cortos de pedaleo intenso alternados con pedaleo suave.',
   'Ajusta el sillín para que la rodilla quede apenas doblada cuando el pedal está abajo. Pedalea cinco minutos con resistencia baja para calentar. Luego alterna 30 segundos de pedaleo rápido con resistencia alta y 90 segundos de pedaleo suave, entre seis y ocho veces. Termina con cinco minutos de pedaleo suave.'),
  ('Pedaleo reclinado continuo', 'Cardiovascular',
   'Pedaleo a ritmo constante con la espalda apoyada.',
   'Ajusta el asiento para que la rodilla quede apenas doblada cuando el pedal está más lejos. Apoya la espalda en el espaldar y sujétate de las manijas laterales. Pedalea a un ritmo constante que puedas sostener mientras hablas con frases cortas. Es una buena opción si tienes molestias en la espalda baja.'),
  ('Extensión de rodilla en máquina', 'Piernas',
   'Aislamiento de cuádriceps estirando la rodilla contra el rodillo.',
   'Ajusta el respaldo para que las rodillas queden alineadas con el eje de la máquina y el rodillo quede sobre los tobillos. Sujétate de las manijas laterales. Estira las piernas hasta casi bloquear las rodillas, sostén un segundo y baja de forma controlada. No uses impulso ni levantes la cadera del asiento.'),
  ('Sentadilla en máquina Smith', 'Piernas',
   'Sentadilla con barra guiada por rieles.',
   'Ubica la barra a la altura de los hombros y apóyala sobre los trapecios. Pon los pies un poco adelante de la barra, al ancho de los hombros. Gira la barra para soltar los seguros y baja llevando la cadera hacia atrás hasta que los muslos queden paralelos al piso. Sube empujando con los talones y vuelve a girar la barra para trabarla al terminar.'),
  ('Press inclinado con barra', 'Pecho',
   'Empuje de barra en banco inclinado, enfocado en la parte alta del pecho.',
   'Acuéstate en el banco inclinado con los ojos bajo la barra y los pies firmes en el piso. Toma la barra un poco más abierta que el ancho de los hombros. Bájala de forma controlada hasta la parte alta del pecho y empújala hacia arriba sin bloquear los codos. Con pesos altos, entrena siempre con un compañero que te asista.'),
  ('Press inclinado con mancuernas', 'Pecho',
   'Empuje de mancuernas en banco inclinado.',
   'Siéntate en el banco inclinado con una mancuerna sobre cada muslo. Recuéstate llevando las mancuernas a la altura del pecho, con las palmas hacia el frente. Empújalas hacia arriba hasta casi juntarlas y bájalas de forma controlada hasta que los codos queden un poco por debajo del banco.'),
  ('Curl en banco Scott', 'Brazos',
   'Flexión de codo con los brazos apoyados en el atril.',
   'Ajusta el asiento para que las axilas queden sobre el borde superior del atril. Toma la barra con las palmas hacia arriba, al ancho de los hombros. Sube la barra doblando los codos sin despegar los brazos del atril. Baja de forma controlada sin estirar del todo los codos para no forzar la articulación.'),
  ('Aperturas en máquina', 'Pecho',
   'Cierre de brazos al frente en máquina guiada.',
   'Ajusta el asiento para que las manijas queden a la altura del pecho. Siéntate con la espalda apoyada y toma las manijas con los codos ligeramente doblados. Junta los brazos al frente apretando el pecho, sostén un segundo y vuelve de forma controlada hasta sentir un estiramiento suave, sin pasar la línea de los hombros.'),
  ('Sentadilla hack', 'Piernas',
   'Sentadilla en máquina con la espalda apoyada en el respaldo.',
   'Apoya la espalda y los hombros en las almohadillas y pon los pies en el centro de la plataforma, al ancho de la cadera. Quita los seguros y baja doblando las rodillas hasta unos 90 grados, sin despegar la espalda. Sube empujando con toda la planta del pie, sin bloquear las rodillas. Vuelve a poner los seguros al terminar.')
on conflict (nombre) do nothing;

-- 3. Enlaces ejercicio — máquina -------------------------------------

insert into public.ejercicio_maquina (ejercicio_id, maquina_id)
select e.id, m.id
from (values
  ('Elíptica continua',               'Elíptica'),
  ('Pedaleo por intervalos',          'Bicicleta estática'),
  ('Pedaleo por intervalos',          'Bicicleta reclinada'),
  ('Pedaleo reclinado continuo',      'Bicicleta reclinada'),
  ('Extensión de rodilla en máquina', 'Extensión de cuádriceps'),
  ('Sentadilla en máquina Smith',     'Máquina Smith'),
  ('Press inclinado con barra',       'Banco inclinado'),
  ('Press inclinado con mancuernas',  'Banco inclinado'),
  ('Press inclinado con mancuernas',  'Mancuernas'),
  ('Curl en banco Scott',             'Banco Scott'),
  ('Aperturas en máquina',            'Máquina de aperturas'),
  ('Sentadilla hack',                 'Sentadilla hack')
) as v (ejercicio, maquina)
join public.ejercicios e on e.nombre = v.ejercicio
join public.maquinas   m on m.nombre = v.maquina
on conflict (ejercicio_id, maquina_id) do nothing;

-- 4. Fotos de referencia (créditos en docs/creditos-imagenes.md).
--    Cinco son de Wikimedia Commons. La de la bicicleta reclinada es
--    una foto del fabricante guardada en el Storage de Supabase
--    (bucket público "maquinas"), solo como referencia.

update public.maquinas set imagen_url =
  'https://upload.wikimedia.org/wikipedia/commons/thumb/7/74/Smith_machine.webp/960px-Smith_machine.webp'
where nombre = 'Máquina Smith' and imagen_url is null;

update public.maquinas set imagen_url =
  'https://upload.wikimedia.org/wikipedia/commons/thumb/0/08/Incline_bench_for_bench_pressing.jpg/960px-Incline_bench_for_bench_pressing.jpg'
where nombre = 'Banco inclinado' and imagen_url is null;

update public.maquinas set imagen_url =
  'https://upload.wikimedia.org/wikipedia/commons/c/cc/PreacherBenchBicepsCurl.JPG'
where nombre = 'Banco Scott' and imagen_url is null;

update public.maquinas set imagen_url =
  'https://upload.wikimedia.org/wikipedia/commons/thumb/c/cf/Pec_deck_Fly.jpg/960px-Pec_deck_Fly.jpg'
where nombre = 'Máquina de aperturas' and imagen_url is null;

update public.maquinas set imagen_url =
  'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/David_Jobson_%26_Ziggy_Chima%3B_machine_hack_squat.jpg/960px-David_Jobson_%26_Ziggy_Chima%3B_machine_hack_squat.jpg'
where nombre = 'Sentadilla hack' and imagen_url is null;

update public.maquinas set imagen_url =
  'https://ovhaqvhomiazygxzhwji.supabase.co/storage/v1/object/public/maquinas/bicicleta_inclinada.jpg'
where nombre = 'Bicicleta reclinada' and imagen_url is null;
