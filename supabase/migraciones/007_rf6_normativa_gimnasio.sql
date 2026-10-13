-- =====================================================================
-- Migración 007 — RF6: normativa real del gimnasio
-- Proyecto de Ingeniería de Software 1, Grupo 8, UIS
--
-- Se corre UNA vez en el SQL Editor de Supabase, sobre la base que ya
-- tiene schema.sql y las migraciones 001 a 006. schema.sql ya incluye
-- estos datos, así que una base creada desde cero no la necesita.
--
-- Qué cambia:
--   No toca la estructura de ninguna tabla. Publica la versión nueva
--   de la normativa con las ocho reglas del gimnasio de la UIS, una por
--   línea, y deja la anterior en el historial (vigente = false), como
--   pide el CU13 (flujo 4a). La app la muestra en el RF6 con su número
--   de versión y su fecha.
--
-- Se puede volver a correr sin problema: si esta misma normativa ya es
-- la vigente, no hace nada.
-- =====================================================================

do $migracion$
declare
  texto constant text := $reglas$1. El uso de toalla es obligatorio.
2. No se permite el ingreso de maletas.
3. Prohibido el consumo de alimentos dentro del gimnasio.
4. Portar ropa adecuada para entrenar.
5. Dejar en el sitio correspondiente los elementos que utilice.
6. Los equipos de trabajo aeróbico pueden usarse máximo por 30 min.
7. Toda persona que haga mal uso de las máquinas e instalaciones quedará suspendida del servicio.
8. Sólo se permite una reserva por día y máximo 3 veces por semana.$reglas$;
begin
  if exists (
    select 1 from public.normativa where vigente and contenido = texto
  ) then
    return;
  end if;

  -- Primero se retira la vigente: el índice normativa_una_vigente no
  -- deja que haya dos a la vez.
  update public.normativa set vigente = false where vigente;

  insert into public.normativa (titulo, contenido, version, vigente)
  values (
    'Normativa del gimnasio',
    texto,
    coalesce((select max(version) from public.normativa), 0) + 1,
    true
  );
end
$migracion$;
