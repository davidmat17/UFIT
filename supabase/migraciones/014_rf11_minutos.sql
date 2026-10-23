-- =====================================================================
-- Migración 014 — RF11: series y repeticiones opcionales, minutos
-- Proyecto de Ingeniería de Software 1, Grupo 8, UIS
--
-- Se corre UNA vez en el SQL Editor de Supabase, después de la 013.
-- schema.sql ya incluye estos cambios. Se puede correr más de una vez.
--
-- Por qué existe (decisión del 23 oct 2026):
--   Ejercicios como la caminata o la elíptica no se cuentan en series ni
--   repeticiones sino en tiempo. Desde ahora cada ejercicio de una rutina
--   lleva repeticiones, minutos o ambos; las series son opcionales.
--
-- Qué cambia:
--   1. rutina_ejercicios.series y .repeticiones aceptan null; series ya
--      no tiene 3 por defecto.
--   2. Columna nueva rutina_ejercicios.minutos, de 1 a 60.
--   3. Regla: repeticiones o minutos, al menos uno.
--   4. crear_rutina() acepta los tres campos opcionales con esa regla.
--      Su firma no cambia, así que la app no se entera de nada más.
-- =====================================================================

alter table public.rutina_ejercicios
  alter column series drop not null,
  alter column series drop default,
  alter column repeticiones drop not null,
  add column if not exists minutos smallint;

alter table public.rutina_ejercicios
  drop constraint if exists rutina_ejercicios_minutos_rango,
  drop constraint if exists rutina_ejercicios_repeticiones_o_minutos,
  -- Un check con null pasa: los rangos solo se revisan si hay valor.
  add constraint rutina_ejercicios_minutos_rango
    check (minutos between 1 and 60),
  add constraint rutina_ejercicios_repeticiones_o_minutos
    check (repeticiones is not null or minutos is not null);

comment on column public.rutina_ejercicios.minutos is
  'Tiempo del ejercicio, de 1 a 60 minutos, para los que se miden en tiempo (caminata, elíptica…). Cada ejercicio lleva repeticiones, minutos o ambos.';


-- p_ejercicios es un arreglo JSON, en el orden en que se muestran:
--   [{"ejercicio_id": 3, "maquina_id": 4, "dias": [1,3,5],
--     "series": 4, "repeticiones": 12, "minutos": null}, ...]
-- series, repeticiones y minutos pueden faltar o ser null, pero cada
-- ejercicio necesita repeticiones o minutos.
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
-- la app muestra tal cual, y no queda nada guardado.
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
  v_minutos  integer;
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
      v_ej      := (v_item ->> 'ejercicio_id')::bigint;
      v_maq     := (v_item ->> 'maquina_id')::bigint;
      v_series  := (v_item ->> 'series')::integer;
      v_reps    := (v_item ->> 'repeticiones')::integer;
      v_minutos := (v_item ->> 'minutos')::integer;
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

    if v_reps is null and v_minutos is null then
      raise exception 'El ejercicio % necesita repeticiones o minutos', v_orden;
    end if;
    if v_series is not null and v_series not between 1 and 10 then
      raise exception 'Las series van de 1 a 10';
    end if;
    if v_reps is not null and v_reps not between 1 and 50 then
      raise exception 'Las repeticiones van de 1 a 50';
    end if;
    if v_minutos is not null and v_minutos not between 1 and 60 then
      raise exception 'Los minutos van de 1 a 60';
    end if;

    insert into public.rutina_ejercicios
      (rutina_id, ejercicio_id, maquina_id, dias, series, repeticiones, minutos, orden)
    values
      (v_rutina, v_ej, v_maq, v_dias, v_series, v_reps, v_minutos, v_orden);
  end loop;

  resultado := 'creada';
  rutina_id := v_rutina;
  return next;
end;
$$;

comment on function public.crear_rutina(text, jsonb, uuid) is
  'Crea una rutina con todos sus ejercicios en una sola transacción, con máximo 3 por persona. Cada ejercicio lleva repeticiones, minutos o ambos. Reintentar con la misma solicitud no la duplica (RF11).';

revoke all on function public.crear_rutina(text, jsonb, uuid) from public, anon;
grant execute on function public.crear_rutina(text, jsonb, uuid) to authenticated;
