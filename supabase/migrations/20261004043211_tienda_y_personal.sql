-- 04 · Tienda y servicios (catálogo, inventario, cajas, ventas) y personal
-- Ver docs/BASE_DE_DATOS.md (secciones 3.5 y 3.6)

create table public.articulos (
  id         uuid primary key default gen_random_uuid(),
  nombre     text not null check (length(btrim(nombre)) between 2 and 80),
  categoria  public.categoria_articulo not null,
  tipo       public.tipo_articulo not null,
  precio_usd numeric(12,2) not null check (precio_usd > 0),
  activo     boolean not null default true,
  creado_en  timestamptz not null default now(),
  check ((categoria = 'servicios') = (tipo = 'servicio'))
);
create unique index articulos_nombre_uq on public.articulos (lower(btrim(nombre)));

create table public.inventario_sucursal (
  sucursal_id  uuid not null references public.sucursales (id),
  articulo_id  uuid not null references public.articulos (id),
  stock        integer not null default 0 check (stock >= 0),
  stock_minimo integer not null default 0 check (stock_minimo >= 0),
  primary key (sucursal_id, articulo_id)
);

create table public.entradas_inventario (
  id          uuid primary key default gen_random_uuid(),
  corte_id    uuid not null,
  sucursal_id uuid not null,
  articulo_id uuid not null references public.articulos (id),
  cantidad    integer not null check (cantidad > 0),
  proveedor   text check (proveedor is null or length(btrim(proveedor)) between 1 and 80),
  creado_por  uuid not null references public.perfiles (id),
  creado_en   timestamptz not null default now(),
  foreign key (corte_id, sucursal_id) references public.cortes (id, sucursal_id)
);

create table public.bajas_inventario (
  id          uuid primary key default gen_random_uuid(),
  corte_id    uuid not null,
  sucursal_id uuid not null,
  articulo_id uuid not null references public.articulos (id),
  cantidad    integer not null check (cantidad > 0),
  motivo      public.motivo_baja not null,
  nota        text check (nota is null or length(btrim(nota)) >= 3),
  creado_por  uuid not null references public.perfiles (id),
  creado_en   timestamptz not null default now(),
  foreign key (corte_id, sucursal_id) references public.cortes (id, sucursal_id),
  check (motivo <> 'otro' or nota is not null)
);

-- "Cierre de caja" en la UI (el arqueo de cada cajero)
create table public.sesiones_caja (
  id                     uuid primary key default gen_random_uuid(),
  sucursal_id            uuid not null references public.sucursales (id),
  cajero_id              uuid not null references public.perfiles (id),
  corte_id               uuid not null,
  fondo_inicial_usd      numeric(12,2) not null check (fondo_inicial_usd >= 0),
  abierta_en             timestamptz not null default now(),
  cerrada_en             timestamptz,
  efectivo_contado_usd   numeric(12,2) check (efectivo_contado_usd >= 0),
  efectivo_esperado_usd  numeric(12,2),
  diferencia_usd         numeric(12,2),
  cierre_forzado         boolean not null default false,
  cerrada_por            uuid references public.perfiles (id),
  motivo_cierre_forzado  text,
  foreign key (corte_id, sucursal_id) references public.cortes (id, sucursal_id),
  unique (id, sucursal_id),
  constraint sesiones_cierre_ck check (
    (cerrada_en is null and efectivo_contado_usd is null and efectivo_esperado_usd is null
       and diferencia_usd is null and cerrada_por is null)
    or
    (cerrada_en is not null and efectivo_contado_usd is not null and efectivo_esperado_usd is not null
       and diferencia_usd is not null and cerrada_por is not null)
  ),
  constraint sesiones_forzado_ck check (
    (cierre_forzado and length(btrim(coalesce(motivo_cierre_forzado, ''))) >= 3 and cerrada_por <> cajero_id)
    or
    (not cierre_forzado and motivo_cierre_forzado is null and (cerrada_por is null or cerrada_por = cajero_id))
  )
);
-- Una sola caja abierta por cajero
create unique index sesiones_una_abierta_uq on public.sesiones_caja (cajero_id) where cerrada_en is null;
create index sesiones_corte_idx on public.sesiones_caja (corte_id);

create table public.contadores_ticket (
  sucursal_id uuid primary key references public.sucursales (id),
  ultimo      bigint not null default 0
);

create table public.ventas (
  id               uuid primary key default gen_random_uuid(),
  sucursal_id      uuid not null,
  sesion_caja_id   uuid not null,
  corte_id         uuid not null,
  cajero_id        uuid not null references public.perfiles (id),
  numero           bigint not null,
  total_usd        numeric(12,2) not null check (total_usd > 0),
  metodo_pago      public.metodo_pago not null,
  recibido_usd     numeric(12,2),
  vuelto_usd       numeric(12,2),
  estado           public.estado_venta not null default 'completada',
  anulada_por      uuid references public.perfiles (id),
  anulada_en       timestamptz,
  motivo_anulacion text,
  creado_en        timestamptz not null default now(),
  foreign key (sesion_caja_id, sucursal_id) references public.sesiones_caja (id, sucursal_id),
  foreign key (corte_id, sucursal_id)       references public.cortes (id, sucursal_id),
  unique (sucursal_id, numero),
  unique (id, sucursal_id),
  constraint ventas_pago_ck check (
    (metodo_pago = 'efectivo' and recibido_usd is not null and vuelto_usd is not null
       and recibido_usd >= total_usd and vuelto_usd = recibido_usd - total_usd)
    or
    (metodo_pago = 'tarjeta' and recibido_usd is null and vuelto_usd is null)
  ),
  constraint ventas_estado_ck check (
    (estado = 'completada' and anulada_por is null and anulada_en is null and motivo_anulacion is null)
    or
    (estado = 'anulada' and anulada_por is not null and anulada_en is not null
       and length(btrim(coalesce(motivo_anulacion, ''))) >= 3)
  )
);
create index ventas_sesion_idx   on public.ventas (sesion_caja_id);
create index ventas_corte_idx    on public.ventas (corte_id);
create index ventas_cajero_idx   on public.ventas (cajero_id, creado_en desc);

create table public.venta_lineas (
  id                  uuid primary key default gen_random_uuid(),
  venta_id            uuid not null,
  sucursal_id         uuid not null,
  articulo_id         uuid not null references public.articulos (id),
  cantidad            integer not null check (cantidad > 0),
  precio_unitario_usd numeric(12,2) not null check (precio_unitario_usd > 0),
  subtotal_usd        numeric(12,2) not null,
  foreign key (venta_id, sucursal_id) references public.ventas (id, sucursal_id),
  check (subtotal_usd = round(cantidad * precio_unitario_usd, 2))
);
create index venta_lineas_venta_idx    on public.venta_lineas (venta_id);
create index venta_lineas_articulo_idx on public.venta_lineas (articulo_id);

-- Personal
create table public.empleados (
  id            uuid primary key default gen_random_uuid(),
  sucursal_id   uuid not null references public.sucursales (id),
  nombre        text not null check (length(btrim(nombre)) between 2 and 80),
  cargo         public.cargo_empleado not null,
  telefono      text check (telefono is null or telefono ~ '^[0-9+() -]{7,20}$'),
  fecha_ingreso date,
  activo        boolean not null default true,
  perfil_id     uuid unique references public.perfiles (id),
  creado_en     timestamptz not null default now(),
  unique (id, sucursal_id)
);

create table public.turnos (
  id          uuid primary key default gen_random_uuid(),
  sucursal_id uuid not null references public.sucursales (id),
  nombre      text not null check (length(btrim(nombre)) between 2 and 40),
  hora_inicio time not null,
  hora_fin    time not null,
  activo      boolean not null default true,
  creado_en   timestamptz not null default now(),
  unique (id, sucursal_id),
  check (hora_inicio <> hora_fin)
);

create table public.asignaciones_turno (
  empleado_id uuid primary key,
  turno_id    uuid not null,
  sucursal_id uuid not null,
  dias        smallint[] not null
    check (cardinality(dias) between 1 and 7 and dias <@ array[1,2,3,4,5,6,7]::smallint[]),
  foreign key (empleado_id, sucursal_id) references public.empleados (id, sucursal_id),
  foreign key (turno_id, sucursal_id)    references public.turnos (id, sucursal_id)
);
create index empleados_sucursal_idx on public.empleados (sucursal_id);
create index turnos_sucursal_idx    on public.turnos (sucursal_id);
