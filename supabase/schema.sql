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
  check (hora_fin > hora_inicio)
);

-- Necesaria para la llave foránea compuesta de reservas (ver abajo).
alter table public.franjas add constraint franjas_id_fecha_unica unique (id, fecha);

comment on table public.franjas is
  'Franjas de una hora, aforo 75. Se generan por adelantado con generar_franjas(). El administrador puede cerrar una franja sin borrarla.';


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
--    Decisión del equipo: un registro por persona que se actualiza, sin
--    historial. La app muestra la foto actual, no la evolución.
-- ---------------------------------------------------------------------

create table public.medidas_antropometricas (
  perfil_id         uuid primary key references public.perfiles (id) on delete cascade,
  peso_kg           numeric(5,2) check (peso_kg > 0 and peso_kg < 400),
  estatura_cm       numeric(5,2) check (estatura_cm > 0 and estatura_cm < 260),
  circ_cintura_cm   numeric(5,2) check (circ_cintura_cm > 0),
  circ_cadera_cm    numeric(5,2) check (circ_cadera_cm > 0),
  circ_pecho_cm     numeric(5,2) check (circ_pecho_cm > 0),
  circ_brazo_cm     numeric(5,2) check (circ_brazo_cm > 0),
  circ_muslo_cm     numeric(5,2) check (circ_muslo_cm > 0),
  actualizado_en    timestamptz not null default now()
);


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
  hora_cierre   time default '21:00'
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
    hora := hora_apertura;
    while hora < hora_cierre loop
      insert into public.franjas (fecha, hora_inicio, hora_fin)
      values (dia, hora, hora + interval '1 hour')
      on conflict (fecha, hora_inicio) do nothing;
      creadas := creadas + 1;
      hora := hora + interval '1 hour';
    end loop;
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

create policy reservas_crear_propia on public.reservas
  for insert with check (perfil_id = auth.uid());

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

create policy medidas_propias on public.medidas_antropometricas
  for all using (perfil_id = auth.uid()) with check (perfil_id = auth.uid());


-- ---------------------------------------------------------------------
-- 12. Datos semilla
--     Lo mínimo para que las pantallas tengan qué mostrar mientras se
--     programan. No son datos reales del gimnasio.
-- ---------------------------------------------------------------------

insert into public.zonas (nombre, descripcion) values
  ('Cardiovascular', 'Trotadoras, elípticas, bicicletas estáticas y remo.'),
  ('Fuerza',         'Peso libre, barras, mancuernas y bancos.'),
  ('Musculación',    'Máquinas guiadas por grupo muscular.');

insert into public.maquinas (zona_id, nombre, descripcion, cantidad) values
  (1, 'Trotadora',            'Banda para caminar y correr con inclinación regulable.', 8),
  (1, 'Elíptica',             'Trabajo cardiovascular de bajo impacto.',                 6),
  (1, 'Bicicleta estática',   'Pedaleo con resistencia ajustable.',                      6),
  (2, 'Banco plano',          'Banco para press de pecho con barra.',                    4),
  (2, 'Rack de sentadilla',   'Soporte para sentadilla con barra olímpica.',             2),
  (2, 'Mancuernas',           'Juego de mancuernas de 2 a 40 kg.',                       1),
  (3, 'Prensa de piernas',    'Máquina guiada para cuádriceps y glúteos.',               2),
  (3, 'Jalón al pecho',       'Polea alta para dorsales.',                               2),
  (3, 'Extensión de cuádriceps', 'Máquina guiada de aislamiento.',                       2);

insert into public.ejercicios (nombre, grupo_muscular, descripcion) values
  ('Caminata en pendiente', 'Cardiovascular', 'Caminar en banda con inclinación entre 5 % y 10 %.'),
  ('Trote continuo',        'Cardiovascular', 'Carrera a ritmo constante.'),
  ('Press de banca',        'Pecho',          'Empuje de barra desde el pecho, acostado en banco plano.'),
  ('Sentadilla con barra',  'Piernas',        'Flexión de rodillas y cadera con barra sobre los trapecios.'),
  ('Prensa de piernas',     'Piernas',        'Empuje de plataforma con las piernas en máquina guiada.'),
  ('Jalón al pecho',        'Espalda',        'Tracción de barra hacia el pecho en polea alta.'),
  ('Curl de bíceps',        'Brazos',         'Flexión de codo con mancuernas.');

insert into public.ejercicio_maquina (ejercicio_id, maquina_id) values
  (1, 1), (2, 1), (3, 4), (4, 5), (5, 7), (6, 8), (7, 6);

insert into public.normativa (titulo, contenido, version, vigente) values
  ('Normativa del gimnasio UFIT',
   'Uso obligatorio de toalla. Desinfectar la máquina después de usarla. Aforo máximo de 75 personas por franja horaria. Cada usuario puede reservar una franja de una hora al día. La reserva se pierde si no se registra el ingreso dentro de los primeros 15 minutos de la franja.',
   1, true);

-- Franjas de las próximas cuatro semanas.
select public.generar_franjas(public.hoy_local(), public.hoy_local() + 28);
