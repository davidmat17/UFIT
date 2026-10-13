-- =====================================================================
-- Migración 003 — RF5: instrucciones de los ejercicios de prueba
-- Proyecto de Ingeniería de Software 1, Grupo 8, UIS
--
-- Se corre UNA vez en el SQL Editor de Supabase, sobre la base que ya
-- tiene schema.sql y las migraciones 001 y 002. schema.sql ya incluye
-- estos datos, así que una base creada desde cero no la necesita.
--
-- Qué cambia:
--   No toca la estructura de ninguna tabla. Solo llena la columna
--   ejercicios.instrucciones de los siete ejercicios semilla, que
--   estaba vacía. La ficha de la máquina del RF5 (HU13) muestra estas
--   instrucciones. Como los demás datos semilla, son de prueba: los
--   reales los carga el administrador con el RF13.
--
-- Se puede volver a correr sin problema: solo actualiza por nombre.
-- =====================================================================

update public.ejercicios set instrucciones =
  'Sube a la trotadora y empieza a caminar a velocidad baja. Sube la inclinación de forma gradual hasta un valor entre 5 % y 10 %. Mantén el tronco erguido y no te sostengas de las barras. Al terminar, baja la inclinación y la velocidad antes de detener la banda.'
where nombre = 'Caminata en pendiente';

update public.ejercicios set instrucciones =
  'Empieza caminando unos minutos para calentar. Sube la velocidad hasta un ritmo que puedas sostener mientras hablas con frases cortas. Apoya primero la parte media del pie y mantén los brazos relajados. Al terminar, baja la velocidad poco a poco antes de detener la banda.'
where nombre = 'Trote continuo';

update public.ejercicios set instrucciones =
  'Acuéstate en el banco con los ojos bajo la barra y los pies apoyados en el piso. Toma la barra un poco más abierta que el ancho de los hombros. Bájala de forma controlada hasta rozar el pecho y empújala hacia arriba sin bloquear los codos. Con pesos altos, entrena siempre con un compañero que te asista.'
where nombre = 'Press de banca';

update public.ejercicios set instrucciones =
  'Ubica la barra en el rack a la altura de los hombros y apóyala sobre los trapecios. Separa los pies al ancho de los hombros. Baja llevando la cadera hacia atrás, con la espalda recta y las rodillas en la dirección de los pies, hasta que los muslos queden paralelos al piso. Sube empujando con los talones. Ajusta los seguros del rack a una altura que te permita soltar la barra si no puedes subir.'
where nombre = 'Sentadilla con barra';

update public.ejercicios set instrucciones =
  'Siéntate con la espalda apoyada en el respaldo y los pies en el centro de la plataforma, al ancho de la cadera. Quita los seguros y baja la plataforma doblando las rodillas hasta unos 90 grados. Empuja hasta casi estirar las piernas, sin bloquear las rodillas. Vuelve a poner los seguros al terminar.'
where nombre = 'Prensa de piernas';

update public.ejercicios set instrucciones =
  'Ajusta el soporte de los muslos y siéntate. Toma la barra con las manos más abiertas que los hombros. Con el pecho al frente, lleva la barra hacia la parte alta del pecho juntando las escápulas. Sube la barra de forma controlada hasta estirar los brazos. No lleves la barra detrás de la nuca.'
where nombre = 'Jalón al pecho';

update public.ejercicios set instrucciones =
  'De pie, con una mancuerna en cada mano y las palmas hacia el frente, deja los codos pegados al cuerpo. Sube las mancuernas doblando los codos, sin balancear el tronco. Baja de forma controlada hasta estirar los brazos.'
where nombre = 'Curl de bíceps';
