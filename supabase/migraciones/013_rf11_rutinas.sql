-- =====================================================================
-- Migración 013 — RF11: crear, consultar y eliminar rutinas
-- Proyecto de Ingeniería de Software 1, Grupo 8, UIS
--
-- Se corre UNA vez en el SQL Editor de Supabase, sobre la base que ya
-- tiene schema.sql y las migraciones anteriores. schema.sql ya incluye
-- estos cambios, así que una base creada desde cero no necesita esta
-- migración.
--
-- Por qué existe:
--   El RF11 (CU11) pide guardar la rutina completa en una sola
--   transacción, que un reintento después de un fallo de red no la
--   duplique, que el servidor rechace la cuarta rutina aunque la pidan
--   dos celulares a la vez, y que eliminar una rutina ya eliminada no
--   sea un error. Con inserciones sueltas desde la app nada de eso se
--   cumple: la rutina podía quedar creada sin sus ejercicios.
--
-- Qué cambia:
--   1. Rangos acordados (23 oct 2026): días de lunes a viernes (el
--      gimnasio no abre el fin de semana), repeticiones de 1 a 50,
--      series de 1 a 10, nombre de 1 a 60 caracteres y de 1 a 20
--      ejercicios por rutina.
--   2. rutinas.solicitud_id: un identificador que la app genera una vez
--      por formulario. Si llega dos veces, la segunda devuelve la rutina
--      que ya existe en vez de crear otra.
--   3. Funciones crear_rutina() y eliminar_rutina().
--   4. Desde la app las tablas de rutinas solo se leen: crear y eliminar
--      pasan por esas funciones.
--
-- Va después de la 012. Se puede correr más de una vez.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Rangos
-- ---------------------------------------------------------------------

alter table public.rutinas
  add column if not exists solicitud_id uuid;

alter table public.rutinas
  drop constraint if exists rutinas_solicitud_unica,
  add constraint rutinas_solicitud_unica unique (solicitud_id);

alter table public.rutinas
  drop constraint if exists rutinas_nombre_longitud,
  add constraint rutinas_nombre_longitud
    check (char_length(btrim(nombre)) between 1 and 60);

alter table public.rutina_ejercicios
  drop constraint if exists rutina_ejercicios_series_check,
  drop constraint if exists rutina_ejercicios_repeticiones_check,
  drop constraint if exists rutina_ejercicios_dias_check,
  drop constraint if exists rutina_ejercicios_dias_check1,
  drop constraint if exists rutina_ejercicios_series_rango,
  drop constraint if exists rutina_ejercicios_repeticiones_rango,
  drop constraint if exists rutina_ejercicios_dias_lunes_a_viernes,
  add constraint rutina_ejercicios_series_rango
    check (series between 1 and 10),
  add constraint rutina_ejercicios_repeticiones_rango
    check (repeticiones between 1 and 50),
  -- Al menos un día, y solo de lunes (1) a viernes (5).
  add constraint rutina_ejercicios_dias_lunes_a_viernes
    check (array_length(dias, 1) between 1 and 5
           and dias <@ array[1, 2, 3, 4, 5]::smallint[]);

comment on column public.rutina_ejercicios.dias is
  'Días de la semana como números: 1 = lunes … 5 = viernes (el gimnasio no abre el fin de semana). Por ejemplo {1,3,5}.';
comment on column public.rutinas.solicitud_id is
  'Lo genera la app una vez por formulario. Si la misma solicitud llega dos veces (reintento tras un fallo de red), no se crea otra rutina.';


-- ---------------------------------------------------------------------
-- 2. crear_rutina()
-- ---------------------------------------------------------------------

-- p_ejercicios es un arreglo JSON, en el orden en que se muestran:
--   [{"ejercicio_id": 3, "maquina_id": 4, "dias": [1,3,5],
--     "series": 4, "repeticiones": 12}, ...]
--
-- Qué devuelve (una sola fila):
--
--   resultado        significado
--   ---------------  ---------------------------------------------------
--   creada           rutina nueva, con todos sus ejercicios
--   ya_creada        esa misma solicitud ya se había guardado (reintento
--                    tras un fallo de red); rutina_id es la que existe
--   maximo_rutinas   ya tiene 3 rutinas; no se crea nada (CU11, 7c)
--   nombre_repetido  ya tiene otra rutina con ese nombre
--
-- Si los datos no son válidos (CU11, 7a y 7b) falla con un mensaje que
-- la app muestra tal cual, y no queda nada guardado. La app valida lo
-- mismo antes de enviar; esto es la última barrera.
create or replace function public.crear_rutina(
  p_nombre      text,
  p_ejercicios  jsonb,
  p_solicitud   uuid
)
returns table (
  resultado  text,
  rutina_id  bigint
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_perfil   uuid := auth.uid();
  v_nombre   text := btrim(coalesce(p_nombre, ''));
  v_rutina   bigint;
  v_item     jsonb;
  v_orden    smallint := 0;
  v_ej       bigint;
  v_maq      bigint;
  v_dias     smallint[];
  v_series   integer;
  v_reps     integer;
  v_vistos   bigint[] := '{}';
begin
  if v_perfil is null then
    raise exception 'Inicia sesión para crear una rutina';
  end if;

  if p_solicitud is null then
    raise exception 'Falta el identificador de la solicitud';
  end if;

  -- Una persona a la vez: dos celulares creando al tiempo se atienden
  -- en orden, así que la cuarta rutina es imposible.
  perform pg_advisory_xact_lock(hashtext('rutinas:' || v_perfil::text));

  select r.id into v_rutina
    from public.rutinas r
   where r.solicitud_id = p_solicitud and r.perfil_id = v_perfil;
  if found then
    resultado := 'ya_creada';
    rutina_id := v_rutina;
    return next;
    return;
  end if;

  if char_length(v_nombre) = 0 then
    raise exception 'Escribe un nombre para la rutina';
  end if;
  if char_length(v_nombre) > 60 then
    raise exception 'El nombre de la rutina puede tener máximo 60 caracteres';
  end if;

  if p_ejercicios is null or jsonb_typeof(p_ejercicios) <> 'array'
     or jsonb_array_length(p_ejercicios) = 0 then
    raise exception 'Agrega al menos un ejercicio a la rutina';
  end if;
  if jsonb_array_length(p_ejercicios) > 20 then
    raise exception 'Una rutina puede tener máximo 20 ejercicios';
  end if;

  if (select count(*) from public.rutinas r where r.perfil_id = v_perfil) >= 3 then
    resultado := 'maximo_rutinas';
    rutina_id := null;
    return next;
    return;
  end if;

  if exists (
    select 1 from public.rutinas r
     where r.perfil_id = v_perfil and lower(r.nombre) = lower(v_nombre)
  ) then
    resultado := 'nombre_repetido';
    rutina_id := null;
    return next;
    return;
  end if;

  insert into public.rutinas (perfil_id, nombre, solicitud_id)
  values (v_perfil, v_nombre, p_solicitud)
  returning id into v_rutina;

  for v_item in select * from jsonb_array_elements(p_ejercicios) loop
    v_orden := v_orden + 1;

    begin
      v_ej     := (v_item ->> 'ejercicio_id')::bigint;
      v_maq    := (v_item ->> 'maquina_id')::bigint;
      v_series := (v_item ->> 'series')::integer;
      v_reps   := (v_item ->> 'repeticiones')::integer;
      select coalesce(array_agg(distinct d::smallint order by d::smallint), '{}')
        into v_dias
        from jsonb_array_elements_text(coalesce(v_item -> 'dias', '[]')) as d;
    exception when others then
      raise exception 'El ejercicio % tiene datos inválidos', v_orden;
    end;

    if v_ej is null or not exists (select 1 from public.ejercicios e where e.id = v_ej) then
      raise exception 'El ejercicio % no existe en el catálogo', v_orden;
    end if;

    if v_ej = any (v_vistos) then
      raise exception 'Un ejercicio solo puede estar una vez en la rutina';
    end if;
    v_vistos := v_vistos || v_ej;

    -- La máquina tiene que ser una de las que sirven para ese ejercicio.
    if v_maq is null or not exists (
      select 1 from public.ejercicio_maquina em
       where em.ejercicio_id = v_ej and em.maquina_id = v_maq
    ) then
      raise exception 'Elige una máquina que sirva para el ejercicio %', v_orden;
    end if;

    if cardinality(v_dias) = 0 then
      raise exception 'Elige al menos un día para el ejercicio %', v_orden;
    end if;
    if not (v_dias <@ array[1, 2, 3, 4, 5]::smallint[]) then
      raise exception 'Los días van de lunes a viernes';
    end if;

    if v_series is null or v_series not between 1 and 10 then
      raise exception 'Las series van de 1 a 10';
    end if;
    if v_reps is null or v_reps not between 1 and 50 then
      raise exception 'Las repeticiones van de 1 a 50';
    end if;

    insert into public.rutina_ejercicios
      (rutina_id, ejercicio_id, maquina_id, dias, series, repeticiones, orden)
    values
      (v_rutina, v_ej, v_maq, v_dias, v_series, v_reps, v_orden);
  end loop;

  resultado := 'creada';
  rutina_id := v_rutina;
  return next;
end;
$$;

comment on function public.crear_rutina(text, jsonb, uuid) is
  'Crea una rutina con todos sus ejercicios en una sola transacción, con máximo 3 por persona. Reintentar con la misma solicitud no la duplica (RF11).';

revoke all on function public.crear_rutina(text, jsonb, uuid) from public, anon;
grant execute on function public.crear_rutina(text, jsonb, uuid) to authenticated;


-- ---------------------------------------------------------------------
-- 3. eliminar_rutina()
-- ---------------------------------------------------------------------

-- Devuelve 'eliminada' o 'ya_eliminada'. Esto último también cuando la
-- rutina es de otra persona: así no se revela si ese id existe.
-- Borra la rutina y, en cascada, sus ejercicios (CU11, 3b y 3c).
create or replace function public.eliminar_rutina(p_rutina_id bigint)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_perfil uuid := auth.uid();
begin
  if v_perfil is null then
    raise exception 'Inicia sesión para eliminar una rutina';
  end if;

  perform pg_advisory_xact_lock(hashtext('rutinas:' || v_perfil::text));

  delete from public.rutinas r
   where r.id = p_rutina_id and r.perfil_id = v_perfil;

  if found then
    return 'eliminada';
  end if;
  return 'ya_eliminada';
end;
$$;

comment on function public.eliminar_rutina(bigint) is
  'Elimina una rutina propia con sus ejercicios. Si ya no existe responde ya_eliminada, sin error (RF11).';

revoke all on function public.eliminar_rutina(bigint) from public, anon;
grant execute on function public.eliminar_rutina(bigint) to authenticated;


-- ---------------------------------------------------------------------
-- 4. Desde la app, las rutinas solo se leen
-- ---------------------------------------------------------------------

drop policy if exists rutinas_propias on public.rutinas;
drop policy if exists rutinas_ver_propias on public.rutinas;
create policy rutinas_ver_propias on public.rutinas
  for select using (perfil_id = auth.uid());

drop policy if exists rutina_ejercicios_propios on public.rutina_ejercicios;
drop policy if exists rutina_ejercicios_ver_propios on public.rutina_ejercicios;
create policy rutina_ejercicios_ver_propios on public.rutina_ejercicios
  for select using (
    exists (select 1 from public.rutinas r where r.id = rutina_id and r.perfil_id = auth.uid())
  );

revoke insert, update, delete on public.rutinas from anon, authenticated;
revoke insert, update, delete on public.rutina_ejercicios from anon, authenticated;
