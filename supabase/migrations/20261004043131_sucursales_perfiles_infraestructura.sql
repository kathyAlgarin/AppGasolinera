-- 02 · Sucursales, perfiles e infraestructura física (tanques, bombas, mangueras)
-- Ver docs/BASE_DE_DATOS.md (secciones 3.1 y 3.2)

create table public.sucursales (
  id           uuid primary key default gen_random_uuid(),
  nombre       text not null check (length(btrim(nombre)) between 2 and 80),
  direccion    text not null check (length(btrim(direccion)) between 3 and 200),
  tiene_tienda boolean not null default false,
  activa       boolean not null default true,
  creado_en    timestamptz not null default now()
);
create unique index sucursales_nombre_uq on public.sucursales (lower(btrim(nombre)));

create table public.perfiles (
  id                    uuid primary key references auth.users (id) on delete restrict,
  correo                text not null check (correo ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
  nombre                text not null check (length(btrim(nombre)) between 2 and 80),
  rol                   public.rol_usuario not null,
  sucursal_id           uuid references public.sucursales (id),
  activo                boolean not null default true,
  debe_cambiar_password boolean not null default true,
  creado_en             timestamptz not null default now(),
  constraint perfiles_rol_sucursal_ck check ((rol = 'gerente_general') = (sucursal_id is null))
);
create unique index perfiles_correo_uq on public.perfiles (lower(correo));
-- Un solo Gerente de Sucursal activo por sucursal
create unique index perfiles_un_gerente_activo_uq
  on public.perfiles (sucursal_id) where rol = 'gerente_sucursal' and activo;
create index perfiles_sucursal_idx on public.perfiles (sucursal_id);

create table public.tanques (
  id                uuid primary key default gen_random_uuid(),
  sucursal_id       uuid not null references public.sucursales (id),
  combustible       public.combustible not null,
  numero            smallint not null default 1 check (numero >= 1),
  capacidad_gal     numeric(12,2) not null check (capacidad_gal > 0),
  nivel_inicial_gal numeric(12,2) not null check (nivel_inicial_gal >= 0),
  creado_en         timestamptz not null default now(),
  unique (sucursal_id, combustible, numero),
  unique (id, sucursal_id),
  check (nivel_inicial_gal <= capacidad_gal)
);

create table public.bombas (
  id          uuid primary key default gen_random_uuid(),
  sucursal_id uuid not null references public.sucursales (id),
  numero      smallint not null check (numero between 1 and 6),
  creado_en   timestamptz not null default now(),
  unique (sucursal_id, numero),
  unique (id, sucursal_id)
);

create table public.mangueras (
  id          uuid primary key default gen_random_uuid(),
  bomba_id    uuid not null,
  sucursal_id uuid not null,
  combustible public.combustible not null,
  creado_en   timestamptz not null default now(),
  foreign key (bomba_id, sucursal_id) references public.bombas (id, sucursal_id),
  unique (bomba_id, combustible),
  unique (id, sucursal_id)
);
