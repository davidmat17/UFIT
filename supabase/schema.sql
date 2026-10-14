-- =====================================================================
-- UFIT — Esquema de base de datos
-- Proyecto de Ingeniería de Software 1, Grupo 8, UIS
--
-- Congelado el 21 de septiembre de 2026. Cambiar algo de aquí exige
-- acuerdo de David y Sergio (ver docs/modelo-de-datos.md).
--
-- Para aplicarlo: Supabase → SQL Editor → pegar este archivo → Run.
-- Es idempotente de arriba hacia abajo si se corre sobre una base vacía.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Tipos enumerados
--    Un enum en vez de texto libre: la base rechaza un valor inventado
--    y los dos vemos la lista completa de estados posibles aquí.
-- ---------------------------------------------------------------------

create type public.rol_usuario as enum ('usuario', 'instructor', 'administrador');

create type public.estado_reserva as enum ('confirmada', 'cancelada', 'asistida', 'no_asistida');

create type public.estado_franja as enum ('abierta', 'cerrada');

create type public.estado_maquina as enum ('disponible', 'mantenimiento', 'retirada');


-- ---------------------------------------------------------------------
-- 2. Personas  (RF1, RF10)
--    Supabase guarda correo y contraseña en auth.users, que no se toca.
--    perfiles extiende esa tabla con los datos del proyecto y comparte
--    su id, así que hay exactamente un perfil por cuenta.
-- ---------------------------------------------------------------------

create table public.perfiles (
  id              uuid primary key references auth.users (id) on delete cascade,
  nombre          text not null,
  apellido        text not null,
  documento       text not null unique,
  correo          text not null unique,
  telefono        text,
  rol             public.rol_usuario not null default 'usuario',
  activo          boolean not null default true,
  creado_en       timestamptz not null default now(),
  actualizado_en  timestamptz not null default now(),

  -- RF1: solo cuentas institucionales. Microsoft deja entrar a
  -- cualquier cuenta; esta restricción es la barrera real.
  constraint perfiles_correo_institucional check (
    lower(correo) like '%@uis.edu.co' or lower(correo) like '%@correo.uis.edu.co'
  )
);

comment on table public.perfiles is
  'Una fila por persona. El rol decide qué puede hacer: usuario reserva, instructor además es asignable a franjas, administrador gestiona contenidos y ve estadísticas.';


-- ---------------------------------------------------------------------
-- 3. Gimnasio  (RF5, RF13)
-- ---------------------------------------------------------------------

create table public.zonas (
  id           smallint generated always as identity primary key,
  nombre       text not null unique,
  descripcion  text,
  activa       boolean not null default true
);

comment on table public.zonas is
  'Cardiovascular, fuerza y musculación. La reserva apunta a una zona; el cupo de 75 es de la franja completa, no de la zona.';

create table public.maquinas (
  id           bigint generated always as identity primary key,
  zona_id      smallint not null references public.zonas (id) on delete restrict,
  nombre       text not null,
  descripcion  text,
  cantidad     smallint not null default 1 check (cantidad > 0),
  estado       public.estado_maquina not null default 'disponible',
  imagen_url   text,
  creado_en    timestamptz not null default now(),
  unique (zona_id, nombre)
);

create table public.ejercicios (
  id               bigint generated always as identity primary key,
  nombre           text not null unique,
  grupo_muscular   text not null,
  descripcion      text,
  instrucciones    text,
  creado_en        timestamptz not null default now()
);

-- Un ejercicio puede hacerse en varias máquinas y una máquina sirve para
-- varios ejercicios: relación muchos a muchos, va en su propia tabla.
create table public.ejercicio_maquina (
  ejercicio_id  bigint not null references public.ejercicios (id) on delete cascade,
  maquina_id    bigint not null references public.maquinas (id) on delete cascade,
  primary key (ejercicio_id, maquina_id)
);


-- ---------------------------------------------------------------------
-- 4. Franjas horarias  (RF2)
--    Una fila por cada hora de cada día. El calendario semanal de la app
--    es una consulta a vista_disponibilidad, que se define más abajo.
-- ---------------------------------------------------------------------

create table public.franjas (
  id           bigint generated always as identity primary key,
  fecha        date not null,
  hora_inicio  time not null,
  hora_fin     time not null,
  cupo_total   smallint not null default 75 check (cupo_total > 0),
  estado       public.estado_franja not null default 'abierta',
  creado_en    timestamptz not null default now(),
  unique (fecha, hora_inicio),
  check (hora_fin > hora_inicio),
  -- El gimnasio abre de lunes a viernes (isodow: 1 = lunes … 7 = domingo),
  -- de 6 a. m. a 8 p. m.
  constraint franjas_solo_lunes_a_viernes
    check (extract(isodow from fecha) <= 5),
  constraint franjas_horario_de_servicio
    check (hora_inicio >= '06:00' and hora_fin <= '20:00')
);

-- Necesaria para la llave foránea compuesta de reservas (ver abajo).
alter table public.franjas add constraint franjas_id_fecha_unica unique (id, fecha);

comment on table public.franjas is
  'Franjas de una hora, aforo 75, de lunes a viernes de 6 a. m. a 8 p. m. Se generan por adelantado con generar_franjas(). El administrador puede cerrar una franja sin borrarla.';


-- ---------------------------------------------------------------------
-- 5. Reservas y asistencia  (RF2, RF3, RF4)
-- ---------------------------------------------------------------------

create table public.reservas (
  id            bigint generated always as identity primary key,
  perfil_id     uuid not null references public.perfiles (id) on delete cascade,
  franja_id     bigint not null,
  fecha         date not null,
  zona_id       smallint not null references public.zonas (id) on delete restrict,
  estado        public.estado_reserva not null default 'confirmada',
  codigo_qr     uuid not null default gen_random_uuid() unique,
  creada_en     timestamptz not null default now(),
  cancelada_en  timestamptz,

  -- La fecha se copia de la franja, pero esta llave foránea compuesta
  -- impide que se desincronicen: solo acepta el par (franja, fecha) que
  -- de verdad existe en franjas.
  foreign key (franja_id, fecha)
    references public.franjas (id, fecha) on delete restrict,

  check ((estado = 'cancelada') = (cancelada_en is not null))
);

-- Máximo una reserva viva por persona por día (una hora diaria de acceso).
-- Es un índice parcial: las canceladas no cuentan, así que se puede
-- cancelar y volver a reservar el mismo día.
create unique index reservas_una_por_dia
  on public.reservas (perfil_id, fecha)
  where estado in ('confirmada', 'asistida');

create index reservas_por_franja on public.reservas (franja_id);
create index reservas_por_perfil on public.reservas (perfil_id, fecha desc);

comment on column public.reservas.codigo_qr is
  'Se genera al crear la reserva y es lo que codifica el QR del RF4. Vence al terminar la franja: la validación la hace registrar_asistencia().';

create table public.asistencias (
  id              bigint generated always as identity primary key,
  reserva_id      bigint not null unique references public.reservas (id) on delete cascade,
  registrada_en   timestamptz not null default now(),
  registrada_por  uuid references public.perfiles (id) on delete set null
);

comment on table public.asistencias is
  'El ingreso real al gimnasio. Una reserva sin fila aquí y con la franja ya vencida es una inasistencia; eso es lo que compara el RF12.';


-- ---------------------------------------------------------------------
-- 6. Entrenamiento  (RF11)
-- ---------------------------------------------------------------------

create table public.rutinas (
  id         bigint generated always as identity primary key,
  perfil_id  uuid not null references public.perfiles (id) on delete cascade,
  nombre     text not null,
  creada_en  timestamptz not null default now(),
  unique (perfil_id, nombre)
);

create table public.rutina_ejercicios (
  id             bigint generated always as identity primary key,
  rutina_id      bigint not null references public.rutinas (id) on delete cascade,
  ejercicio_id   bigint not null references public.ejercicios (id) on delete restrict,
  maquina_id     bigint references public.maquinas (id) on delete set null,
  dias           smallint[] not null,
  series         smallint not null default 3 check (series > 0),
  repeticiones   smallint not null check (repeticiones > 0),
  orden          smallint not null default 1,
  unique (rutina_id, ejercicio_id),
  check (array_length(dias, 1) between 1 and 7),
  check (dias <@ array[1, 2, 3, 4, 5, 6, 7]::smallint[])
);

comment on column public.rutina_ejercicios.dias is
  'Días de la semana como números: 1 = lunes … 7 = domingo. Por ejemplo {1,3,5}.';


-- ---------------------------------------------------------------------
-- 7. Medidas antropométricas  (RF8)
--    Decisión del equipo (1 oct 2026): con historial. Cada medición es
--    una fila con su fecha; la app muestra la última y la evolución.
--    Una medición no se edita: se registra otra o se borra.
-- ---------------------------------------------------------------------

create table public.medidas_antropometricas (
  id                bigint generated always as identity primary key,
  perfil_id         uuid not null references public.perfiles (id) on delete cascade,
  peso_kg           numeric(5,2) not null check (peso_kg > 0 and peso_kg < 400),
  estatura_cm       numeric(5,2) not null check (estatura_cm > 0 and estatura_cm < 260),
  circ_cintura_cm   numeric(5,2) check (circ_cintura_cm > 0),
  circ_cadera_cm    numeric(5,2) check (circ_cadera_cm > 0),
  circ_pecho_cm     numeric(5,2) check (circ_pecho_cm > 0),
  circ_brazo_cm     numeric(5,2) check (circ_brazo_cm > 0),
  circ_muslo_cm     numeric(5,2) check (circ_muslo_cm > 0),
  registrada_en     timestamptz not null default now()
);

create index medidas_por_perfil
  on public.medidas_antropometricas (perfil_id, registrada_en desc);


-- ---------------------------------------------------------------------
-- 8. Normativa e instructores  (RF6, RF7, RF13)
-- ---------------------------------------------------------------------

create table public.normativa (
  id             bigint generated always as identity primary key,
  titulo         text not null,
  contenido      text not null,
  version        smallint not null,
  vigente        boolean not null default false,
  publicada_en   timestamptz not null default now(),
  publicada_por  uuid references public.perfiles (id) on delete set null
);

-- Solo puede haber una normativa vigente a la vez; las anteriores quedan
-- como historial.
create unique index normativa_una_vigente on public.normativa (vigente) where vigente;

create table public.asignaciones_instructor (
  id             bigint generated always as identity primary key,
  instructor_id  uuid not null references public.perfiles (id) on delete cascade,
  franja_id      bigint not null references public.franjas (id) on delete cascade,
  zona_id        smallint references public.zonas (id) on delete set null,
  creada_en      timestamptz not null default now(),
  unique (instructor_id, franja_id)
);

comment on table public.asignaciones_instructor is
  'El administrador asigna instructores a franjas (RF13) y el usuario consulta esa agenda (RF7).';


-- ---------------------------------------------------------------------
-- 9. Vista de disponibilidad  (RF2)
--    El calendario semanal consulta esto. Contar reservas en el momento
--    evita guardar un contador que se pueda desincronizar.
-- ---------------------------------------------------------------------

create view public.vista_disponibilidad as
select
  f.id                as franja_id,
  f.fecha,
  f.hora_inicio,
  f.hora_fin,
  f.cupo_total,
  f.estado,
  count(r.id) filter (where r.estado in ('confirmada', 'asistida'))          as cupos_ocupados,
  f.cupo_total - count(r.id) filter (where r.estado in ('confirmada', 'asistida')) as cupos_disponibles
from public.franjas f
left join public.reservas r on r.franja_id = f.id
group by f.id;

comment on view public.vista_disponibilidad is
  'Verde en la app = cupos_disponibles > 0 y estado = abierta. Rojo = lo contrario.';


-- ---------------------------------------------------------------------
-- 10. Funciones
-- ---------------------------------------------------------------------

-- El rol de quien está usando la app. Es security definer a propósito:
-- las políticas de seguridad consultan perfiles, y sin esto Postgres
-- entraría en recursión infinita al revisar los permisos de perfiles.
create or replace function public.rol_actual()
returns public.rol_usuario
language sql
stable
security definer
set search_path = public
as $$
  select rol from public.perfiles where id = auth.uid();
$$;

create or replace function public.es_administrador()
returns boolean
language sql
stable
as $$
  select public.rol_actual() = 'administrador';
$$;

-- La fecha de hoy en Bucaramanga, no en UTC. A partir de las 7 p. m.
-- hora local, current_date ya devolvería el día siguiente.
create or replace function public.hoy_local()
returns date
language sql
stable
as $$
  select timezone('America/Bogota', now())::date;
$$;

-- Crea las franjas de un rango de fechas. El gimnasio abre de 6 a 21.
create or replace function public.generar_franjas(
  desde date,
  hasta date,
  hora_apertura time default '06:00',
  hora_cierre   time default '20:00'
)
returns integer
language plpgsql
as $$
declare
  dia    date;
  hora   time;
  creadas integer := 0;
begin
  dia := desde;
  while dia <= hasta loop
    -- isodow: 1 = lunes … 7 = domingo. El gimnasio no abre el fin de
    -- semana.
    if extract(isodow from dia) <= 5 then
      hora := hora_apertura;
      while hora < hora_cierre loop
        insert into public.franjas (fecha, hora_inicio, hora_fin)
        values (dia, hora, hora + interval '1 hour')
        on conflict (fecha, hora_inicio) do nothing;
        creadas := creadas + 1;
        hora := hora + interval '1 hour';
      end loop;
    end if;
    dia := dia + 1;
  end loop;
  return creadas;
end;
$$;

-- Máximo 3 rutinas por usuario (RF11).
create or replace function public.limitar_rutinas()
returns trigger
language plpgsql
as $$
begin
  if (select count(*) from public.rutinas where perfil_id = new.perfil_id) >= 3 then
    raise exception 'Cada usuario puede tener máximo 3 rutinas';
  end if;
  return new;
end;
$$;

create trigger rutinas_maximo_tres
  before insert on public.rutinas
  for each row execute function public.limitar_rutinas();

-- Máximo 3 reservas por persona por semana, de lunes a domingo (regla 8
-- de la normativa). Cuentan todas menos las canceladas: una reserva a la
-- que no se asistió también gastó su cupo de la semana. Cancelar sí lo
-- devuelve.
create or replace function public.limitar_reservas_semana()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  lunes constant date := date_trunc('week', new.fecha)::date;
begin
  if new.estado = 'cancelada' then
    return new;
  end if;

  -- Mientras cuenta, bloquea las reservas de esta persona: así dos
  -- reservas enviadas al mismo tiempo no pasan las dos.
  perform pg_advisory_xact_lock(hashtext(new.perfil_id::text));

  if (select count(*)
        from public.reservas
       where perfil_id = new.perfil_id
         and estado <> 'cancelada'
         and fecha between lunes and lunes + 6
         and id is distinct from new.id) >= 3 then
    raise exception 'Ya tienes 3 reservas esta semana. La normativa del gimnasio permite máximo 3 por semana.';
  end if;
  return new;
end;
$$;

create trigger reservas_maximo_tres_por_semana
  before insert or update of estado, fecha on public.reservas
  for each row execute function public.limitar_reservas_semana();

-- Registra el ingreso a partir del QR (RF4). Devuelve la reserva o falla
-- con un mensaje que la app muestra tal cual.
create or replace function public.registrar_asistencia(qr uuid)
returns public.reservas
language plpgsql
security definer
set search_path = public
as $$
declare
  reserva public.reservas;
  franja  public.franjas;
  -- La base corre en UTC y las franjas están en hora de Bucaramanga.
  -- Sin esta conversión, la validación se corre cinco horas.
  ahora   timestamp := timezone('America/Bogota', now());
begin
  select * into reserva from public.reservas where codigo_qr = qr;
  if reserva is null then
    raise exception 'Código no válido';
  end if;

  select * into franja from public.franjas where id = reserva.franja_id;

  if reserva.estado = 'cancelada' then
    raise exception 'La reserva fue cancelada';
  end if;

  if ahora < (franja.fecha + franja.hora_inicio) - interval '15 minutes'
     or ahora > (franja.fecha + franja.hora_fin) then
    raise exception 'El código no corresponde a la franja actual';
  end if;

  if exists (select 1 from public.asistencias where reserva_id = reserva.id) then
    raise exception 'El ingreso ya fue registrado';
  end if;

  insert into public.asistencias (reserva_id, registrada_por)
  values (reserva.id, auth.uid());

  update public.reservas set estado = 'asistida' where id = reserva.id
  returning * into reserva;

  return reserva;
end;
$$;

-- Qué devuelve, una fila por franja pedida (sin repetidas):
--
--   resultado             significado
--   --------------------  -------------------------------------------
--   creada                reserva nueva
--   ya_reservada          ya tenías esa franja; es la misma reserva.
--                         Hace seguro reintentar si se cortó la red.
--   otra_reserva_ese_dia  ya tienes otra franja ese día (máx. una)
--   sin_cupo              la franja llegó al aforo
--   franja_cerrada        el administrador la cerró
--   franja_pasada         la franja ya terminó
--   franja_inexistente    el id no existe
--
-- Lo que no depende de una franja en concreto (sin sesión, cuenta
-- inactiva, zona inválida, lista vacía) no devuelve filas: falla con un
-- mensaje que la app muestra tal cual, como registrar_asistencia().
create or replace function public.reservar_cupos(
  p_franjas  bigint[],
  p_zona_id  smallint
)
returns table (
  franja     bigint,
  resultado  text,
  reserva    jsonb
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_perfil    uuid := auth.uid();
  -- La base corre en UTC y las franjas están en hora de Bucaramanga.
  v_ahora     timestamp := timezone('America/Bogota', now());
  v_ids       bigint[];
  v_id        bigint;
  v_franja    public.franjas;
  v_previa    public.reservas;
  v_nueva     public.reservas;
  v_ocupados  integer;
begin
  if v_perfil is null then
    raise exception 'Inicia sesión para reservar un cupo';
  end if;

  if not exists (
    select 1 from public.perfiles p where p.id = v_perfil and p.activo
  ) then
    raise exception 'Tu cuenta no está activa';
  end if;

  if not exists (
    select 1 from public.zonas z where z.id = p_zona_id and z.activa
  ) then
    raise exception 'La zona elegida no está disponible';
  end if;

  -- Sin repetidas y en orden. El orden importa: dos personas reservando
  -- varias franjas a la vez toman los bloqueos en la misma secuencia y
  -- no se traban una a la otra.
  select array_agg(distinct x order by x) into v_ids
    from unnest(p_franjas) as x
   where x is not null;

  if v_ids is null then
    raise exception 'Elige al menos una franja';
  end if;

  if array_length(v_ids, 1) > 60 then
    raise exception 'Se pueden reservar como máximo 60 franjas a la vez';
  end if;

  foreach v_id in array v_ids loop
    franja  := v_id;
    reserva := null;

    -- El bloqueo dura hasta el final de la transacción. Quien llegue
    -- después a la misma franja espera aquí, y cuando le toca el turno
    -- ya ve la reserva de quien lo precedió.
    select * into v_franja from public.franjas f where f.id = v_id for update;

    if not found then
      resultado := 'franja_inexistente';

    elsif v_franja.estado <> 'abierta' then
      resultado := 'franja_cerrada';

    elsif (v_franja.fecha + v_franja.hora_fin) <= v_ahora then
      resultado := 'franja_pasada';

    else
      select * into v_previa
        from public.reservas r
       where r.perfil_id = v_perfil
         and r.fecha = v_franja.fecha
         and r.estado in ('confirmada', 'asistida');

      if found then
        if v_previa.franja_id = v_franja.id then
          resultado := 'ya_reservada';
          reserva   := to_jsonb(v_previa);
        else
          resultado := 'otra_reserva_ese_dia';
        end if;

      else
        select count(*) into v_ocupados
          from public.reservas r
         where r.franja_id = v_franja.id
           and r.estado in ('confirmada', 'asistida');

        if v_ocupados >= v_franja.cupo_total then
          resultado := 'sin_cupo';
        else
          insert into public.reservas (perfil_id, franja_id, fecha, zona_id)
          values (v_perfil, v_franja.id, v_franja.fecha, p_zona_id)
          returning * into v_nueva;

          resultado := 'creada';
          reserva   := to_jsonb(v_nueva);
        end if;
      end if;
    end if;

    return next;
  end loop;
end;
$$;

comment on function public.reservar_cupos(bigint[], smallint) is
  'Reserva una o varias franjas para quien tiene la sesión abierta, con el aforo garantizado. Una fila de resultado por franja. Es la única vía para crear reservas (RF2).';

-- Solo quien inició sesión. Sin esto, PostgREST la expone también a anon.
revoke all on function public.reservar_cupos(bigint[], smallint) from public, anon;
grant execute on function public.reservar_cupos(bigint[], smallint) to authenticated;

-- Mantiene actualizado_en al día.
create or replace function public.tocar_actualizado_en()
returns trigger
language plpgsql
as $$
begin
  new.actualizado_en := now();
  return new;
end;
$$;

create trigger perfiles_actualizado_en
  before update on public.perfiles
  for each row execute function public.tocar_actualizado_en();


-- ---------------------------------------------------------------------
-- 11. Seguridad a nivel de fila (RLS)
--     Sin esto, cualquiera con la clave pública de la app puede leer
--     todas las tablas. Con esto, la base misma impide que un usuario
--     vea las reservas o las medidas de otro.
-- ---------------------------------------------------------------------

alter table public.perfiles                 enable row level security;
alter table public.zonas                    enable row level security;
alter table public.maquinas                 enable row level security;
alter table public.ejercicios               enable row level security;
alter table public.ejercicio_maquina        enable row level security;
alter table public.franjas                  enable row level security;
alter table public.reservas                 enable row level security;
alter table public.asistencias              enable row level security;
alter table public.rutinas                  enable row level security;
alter table public.rutina_ejercicios        enable row level security;
alter table public.medidas_antropometricas  enable row level security;
alter table public.normativa                enable row level security;
alter table public.asignaciones_instructor  enable row level security;

-- Perfiles: cada quien ve y edita el suyo; el administrador ve todos.
create policy perfiles_ver_propio on public.perfiles
  for select using (id = auth.uid() or public.es_administrador());

-- Al crear el perfil, el correo tiene que ser el de la sesión: nadie se
-- registra con el correo de otro.
create policy perfiles_crear_propio on public.perfiles
  for insert with check (
    id = auth.uid()
    and lower(correo) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

create policy perfiles_editar_propio on public.perfiles
  for update using (id = auth.uid()) with check (id = auth.uid());

-- Permisos por columna: las políticas dicen qué filas, esto dice qué
-- columnas. Sin esto, un usuario podría ponerse rol administrador.
-- rol, activo y correo se cambian desde el panel o por el RF13.
revoke insert, update on public.perfiles from anon, authenticated;
grant insert (id, nombre, apellido, documento, correo, telefono)
  on public.perfiles to authenticated;
grant update (nombre, apellido, telefono)
  on public.perfiles to authenticated;

-- Catálogo, franjas y normativa: los lee cualquiera que haya iniciado
-- sesión; la normativa vigente la lee incluso quien no inició sesión
-- (RF6). Solo el administrador escribe.
create policy zonas_lectura on public.zonas
  for select using (true);
create policy zonas_admin on public.zonas
  for all using (public.es_administrador()) with check (public.es_administrador());

create policy maquinas_lectura on public.maquinas
  for select using (true);
create policy maquinas_admin on public.maquinas
  for all using (public.es_administrador()) with check (public.es_administrador());

create policy ejercicios_lectura on public.ejercicios
  for select using (true);
create policy ejercicios_admin on public.ejercicios
  for all using (public.es_administrador()) with check (public.es_administrador());

create policy ejercicio_maquina_lectura on public.ejercicio_maquina
  for select using (true);
create policy ejercicio_maquina_admin on public.ejercicio_maquina
  for all using (public.es_administrador()) with check (public.es_administrador());

create policy franjas_lectura on public.franjas
  for select using (true);
create policy franjas_admin on public.franjas
  for all using (public.es_administrador()) with check (public.es_administrador());

create policy normativa_lectura on public.normativa
  for select using (vigente or public.es_administrador());
create policy normativa_admin on public.normativa
  for all using (public.es_administrador()) with check (public.es_administrador());

create policy asignaciones_lectura on public.asignaciones_instructor
  for select using (true);
create policy asignaciones_admin on public.asignaciones_instructor
  for all using (public.es_administrador()) with check (public.es_administrador());

-- Reservas: cada quien las suyas. El administrador las ve todas, que es
-- lo que hace posible el RF12.
create policy reservas_ver_propias on public.reservas
  for select using (perfil_id = auth.uid() or public.es_administrador());

-- Las reservas se crean solo con reservar_cupos() (sección 10), que
-- garantiza el aforo de la franja. No hay política de INSERT: desde la
-- app no se puede insertar directo en la tabla.
revoke insert on public.reservas from anon, authenticated;

-- Pendiente para el RF3: esta política deja actualizar CUALQUIER columna
-- de la reserva propia, incluida franja_id, lo que permitiría saltarse el
-- aforo. Cancelar debería pasar por una función como reservar_cupos()
-- (con la regla de las 3 horas) y quitarse el UPDATE directo.
create policy reservas_cancelar_propia on public.reservas
  for update using (perfil_id = auth.uid()) with check (perfil_id = auth.uid());

create policy asistencias_ver on public.asistencias
  for select using (
    public.es_administrador()
    or exists (
      select 1 from public.reservas r
      where r.id = reserva_id and r.perfil_id = auth.uid()
    )
  );

-- Rutinas y medidas: estrictamente privadas de cada usuario.
create policy rutinas_propias on public.rutinas
  for all using (perfil_id = auth.uid()) with check (perfil_id = auth.uid());

create policy rutina_ejercicios_propios on public.rutina_ejercicios
  for all using (
    exists (select 1 from public.rutinas r where r.id = rutina_id and r.perfil_id = auth.uid())
  ) with check (
    exists (select 1 from public.rutinas r where r.id = rutina_id and r.perfil_id = auth.uid())
  );

-- Medidas: cada quien ve, registra y borra solo las suyas. Sin
-- política de edición, y la app no escribe el id ni la fecha.
create policy medidas_ver_propias on public.medidas_antropometricas
  for select using (perfil_id = auth.uid());
create policy medidas_crear_propias on public.medidas_antropometricas
  for insert with check (perfil_id = auth.uid());
create policy medidas_borrar_propias on public.medidas_antropometricas
  for delete using (perfil_id = auth.uid());

revoke insert, update on public.medidas_antropometricas from anon, authenticated;
grant insert (perfil_id, peso_kg, estatura_cm, circ_cintura_cm, circ_cadera_cm,
              circ_pecho_cm, circ_brazo_cm, circ_muslo_cm)
  on public.medidas_antropometricas to authenticated;


-- ---------------------------------------------------------------------
-- 12. Datos semilla
--     Lo mínimo para que las pantallas tengan qué mostrar mientras se
--     programan. No son datos reales del gimnasio. Las fotos de las
--     máquinas están en el bucket público "maquinas" del Storage
--     (archivos en supabase/fotos-maquinas/, créditos en
--     docs/creditos-imagenes.md).
-- ---------------------------------------------------------------------

insert into public.zonas (nombre, descripcion) values
  ('Cardiovascular', 'Trotadoras, elípticas, bicicletas estáticas y remo.'),
  ('Fuerza',         'Peso libre, barras, mancuernas y bancos.'),
  ('Musculación',    'Máquinas guiadas por grupo muscular.');

insert into public.maquinas (zona_id, nombre, descripcion, cantidad, imagen_url) values
  (1, 'Trotadora', 'Banda para caminar y correr con inclinación regulable.', 8,
   'https://ovhaqvhomiazygxzhwji.supabase.co/storage/v1/object/public/maquinas/trotadora.jpg'),
  (1, 'Elíptica', 'Trabajo cardiovascular de bajo impacto.', 6,
   'https://ovhaqvhomiazygxzhwji.supabase.co/storage/v1/object/public/maquinas/eliptica.jpg'),
  (1, 'Bicicleta estática', 'Pedaleo con resistencia ajustable.', 6,
   'https://ovhaqvhomiazygxzhwji.supabase.co/storage/v1/object/public/maquinas/bicicleta-estatica.jpg'),
  (2, 'Banco plano', 'Banco para press de pecho con barra.', 4,
   'https://ovhaqvhomiazygxzhwji.supabase.co/storage/v1/object/public/maquinas/banco-plano.jpg'),
  (2, 'Rack de sentadilla', 'Soporte para sentadilla con barra olímpica.', 2,
   'https://ovhaqvhomiazygxzhwji.supabase.co/storage/v1/object/public/maquinas/rack-de-sentadilla.jpg'),
  (2, 'Mancuernas', 'Juego de mancuernas de 2 a 40 kg.', 1,
   'https://ovhaqvhomiazygxzhwji.supabase.co/storage/v1/object/public/maquinas/mancuernas.jpg'),
  (3, 'Prensa de piernas', 'Máquina guiada para cuádriceps y glúteos.', 2,
   'https://ovhaqvhomiazygxzhwji.supabase.co/storage/v1/object/public/maquinas/prensa-de-piernas.jpg'),
  (3, 'Jalón al pecho', 'Polea alta para dorsales.', 2,
   'https://ovhaqvhomiazygxzhwji.supabase.co/storage/v1/object/public/maquinas/jalon-al-pecho.jpg'),
  (3, 'Extensión de cuádriceps', 'Máquina guiada de aislamiento.', 2,
   'https://ovhaqvhomiazygxzhwji.supabase.co/storage/v1/object/public/maquinas/extension-de-cuadriceps.jpg');

insert into public.ejercicios (nombre, grupo_muscular, descripcion, instrucciones) values
  ('Caminata en pendiente', 'Cardiovascular',
   'Caminar en banda con inclinación entre 5 % y 10 %.',
   'Sube a la trotadora y empieza a caminar a velocidad baja. Sube la inclinación de forma gradual hasta un valor entre 5 % y 10 %. Mantén el tronco erguido y no te sostengas de las barras. Al terminar, baja la inclinación y la velocidad antes de detener la banda.'),
  ('Trote continuo', 'Cardiovascular',
   'Carrera a ritmo constante.',
   'Empieza caminando unos minutos para calentar. Sube la velocidad hasta un ritmo que puedas sostener mientras hablas con frases cortas. Apoya primero la parte media del pie y mantén los brazos relajados. Al terminar, baja la velocidad poco a poco antes de detener la banda.'),
  ('Press de banca', 'Pecho',
   'Empuje de barra desde el pecho, acostado en banco plano.',
   'Acuéstate en el banco con los ojos bajo la barra y los pies apoyados en el piso. Toma la barra un poco más abierta que el ancho de los hombros. Bájala de forma controlada hasta rozar el pecho y empújala hacia arriba sin bloquear los codos. Con pesos altos, entrena siempre con un compañero que te asista.'),
  ('Sentadilla con barra', 'Piernas',
   'Flexión de rodillas y cadera con barra sobre los trapecios.',
   'Ubica la barra en el rack a la altura de los hombros y apóyala sobre los trapecios. Separa los pies al ancho de los hombros. Baja llevando la cadera hacia atrás, con la espalda recta y las rodillas en la dirección de los pies, hasta que los muslos queden paralelos al piso. Sube empujando con los talones. Ajusta los seguros del rack a una altura que te permita soltar la barra si no puedes subir.'),
  ('Prensa de piernas', 'Piernas',
   'Empuje de plataforma con las piernas en máquina guiada.',
   'Siéntate con la espalda apoyada en el respaldo y los pies en el centro de la plataforma, al ancho de la cadera. Quita los seguros y baja la plataforma doblando las rodillas hasta unos 90 grados. Empuja hasta casi estirar las piernas, sin bloquear las rodillas. Vuelve a poner los seguros al terminar.'),
  ('Jalón al pecho', 'Espalda',
   'Tracción de barra hacia el pecho en polea alta.',
   'Ajusta el soporte de los muslos y siéntate. Toma la barra con las manos más abiertas que los hombros. Con el pecho al frente, lleva la barra hacia la parte alta del pecho juntando las escápulas. Sube la barra de forma controlada hasta estirar los brazos. No lleves la barra detrás de la nuca.'),
  ('Curl de bíceps', 'Brazos',
   'Flexión de codo con mancuernas.',
   'De pie, con una mancuerna en cada mano y las palmas hacia el frente, deja los codos pegados al cuerpo. Sube las mancuernas doblando los codos, sin balancear el tronco. Baja de forma controlada hasta estirar los brazos.');

insert into public.ejercicio_maquina (ejercicio_id, maquina_id) values
  (1, 1), (2, 1), (3, 4), (4, 5), (5, 7), (6, 8), (7, 6);

-- Catálogo ampliado (migración 005): máquinas vistas en la foto del
-- gimnasio de la UIS y ejercicios para las que no tenían ninguno.
-- Se enlazan por nombre.

-- Máquinas nuevas -------------------------------------------------

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

-- Ejercicios nuevos -----------------------------------------------

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

-- Enlaces ejercicio — máquina -------------------------------------

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

-- Fotos de referencia de las máquinas nuevas, en el Storage
-- (créditos en docs/creditos-imagenes.md).

update public.maquinas set imagen_url =
  'https://ovhaqvhomiazygxzhwji.supabase.co/storage/v1/object/public/maquinas/maquina-smith.jpg'
where nombre = 'Máquina Smith' and imagen_url is null;

update public.maquinas set imagen_url =
  'https://ovhaqvhomiazygxzhwji.supabase.co/storage/v1/object/public/maquinas/banco-inclinado.jpg'
where nombre = 'Banco inclinado' and imagen_url is null;

update public.maquinas set imagen_url =
  'https://ovhaqvhomiazygxzhwji.supabase.co/storage/v1/object/public/maquinas/banco-scott.jpg'
where nombre = 'Banco Scott' and imagen_url is null;

update public.maquinas set imagen_url =
  'https://ovhaqvhomiazygxzhwji.supabase.co/storage/v1/object/public/maquinas/maquina-de-aperturas.jpg'
where nombre = 'Máquina de aperturas' and imagen_url is null;

update public.maquinas set imagen_url =
  'https://ovhaqvhomiazygxzhwji.supabase.co/storage/v1/object/public/maquinas/sentadilla-hack.jpg'
where nombre = 'Sentadilla hack' and imagen_url is null;

update public.maquinas set imagen_url =
  'https://ovhaqvhomiazygxzhwji.supabase.co/storage/v1/object/public/maquinas/bicicleta-reclinada.jpg'
where nombre = 'Bicicleta reclinada' and imagen_url is null;

-- La versión 1 era de prueba y queda en el historial; la 2 es la
-- normativa real del gimnasio de la UIS (migración 007), una regla por
-- línea.
insert into public.normativa (titulo, contenido, version, vigente) values
  ('Normativa del gimnasio UFIT',
   'Uso obligatorio de toalla. Desinfectar la máquina después de usarla. Aforo máximo de 75 personas por franja horaria. Cada usuario puede reservar una franja de una hora al día. La reserva se pierde si no se registra el ingreso dentro de los primeros 15 minutos de la franja.',
   1, false),
  ('Normativa del gimnasio',
   $reglas$1. El uso de toalla es obligatorio.
2. No se permite el ingreso de maletas.
3. Prohibido el consumo de alimentos dentro del gimnasio.
4. Portar ropa adecuada para entrenar.
5. Dejar en el sitio correspondiente los elementos que utilice.
6. Los equipos de trabajo aeróbico pueden usarse máximo por 30 min.
7. Toda persona que haga mal uso de las máquinas e instalaciones quedará suspendida del servicio.
8. Sólo se permite una reserva por día y máximo 3 veces por semana.$reglas$,
   2, true);

-- Franjas de las próximas cuatro semanas.
select public.generar_franjas(public.hoy_local(), public.hoy_local() + 28);
