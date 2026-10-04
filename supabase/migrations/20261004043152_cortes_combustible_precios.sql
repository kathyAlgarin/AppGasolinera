-- 03 · Cortes de combustible, compras, pérdidas, vaciados, ajustes y precios
-- Ver docs/BASE_DE_DATOS.md (secciones 3.3 y 3.4)

create table public.cortes (
  id              uuid primary key default gen_random_uuid(),
  sucursal_id     uuid not null references public.sucursales (id),
  secuencia       integer not null check (secuencia >= 1),
  estado          public.estado_corte not null default 'en_curso',
  abierto_en      timestamptz not null default now(),
  cerrado_en      timestamptz,
  cerrado_por     uuid references public.perfiles (id),
  tipo            public.tipo_corte,
  fecha_operativa date,
  creado_en       timestamptz not null default now(),
  unique (sucursal_id, secuencia),
  unique (id, sucursal_id),
  constraint cortes_estado_ck check (
    (estado = 'en_curso' and cerrado_en is null and cerrado_por is null and tipo is null and fecha_operativa is null)
    or
    (estado = 'cerrado' and cerrado_en is not null and cerrado_por is not null and tipo is not null and fecha_operativa is not null)
  )
);
-- Un solo corte en curso por sucursal
create unique index cortes_uno_en_curso_uq on public.cortes (sucursal_id) where estado = 'en_curso';
-- Máximo un corte de cada tipo por día operativo (=> 2 cortes por día)
create unique index cortes_fecha_tipo_uq on public.cortes (sucursal_id, fecha_operativa, tipo) where estado = 'cerrado';

-- Borrador por bomba: una fila por manguera con su lectura final guardada
create table public.lecturas_manguera (
  id                         uuid primary key default gen_random_uuid(),
  corte_id                   uuid not null,
  sucursal_id                uuid not null,
  manguera_id                uuid not null,
  lectura_inicial_manual_gal numeric(12,2) check (lectura_inicial_manual_gal >= 0), -- solo en el primer corte
  lectura_final_gal          numeric(12,2) not null check (lectura_final_gal >= 0),
  guardada_en                timestamptz not null default now(),
  foreign key (corte_id, sucursal_id)    references public.cortes (id, sucursal_id),
  foreign key (manguera_id, sucursal_id) references public.mangueras (id, sucursal_id),
  unique (corte_id, manguera_id)
);

create table public.cambios_medidor (
  id                        uuid primary key default gen_random_uuid(),
  corte_id                  uuid not null,
  sucursal_id               uuid not null,
  manguera_id               uuid not null,
  lectura_final_viejo_gal   numeric(12,2) not null check (lectura_final_viejo_gal >= 0),
  lectura_inicial_nuevo_gal numeric(12,2) not null check (lectura_inicial_nuevo_gal >= 0),
  nota                      text not null check (length(btrim(nota)) >= 3),
  registrado_por            uuid not null references public.perfiles (id),
  creado_en                 timestamptz not null default now(),
  foreign key (corte_id, sucursal_id)    references public.cortes (id, sucursal_id),
  foreign key (manguera_id, sucursal_id) references public.mangueras (id, sucursal_id),
  unique (corte_id, manguera_id)
);

create table public.niveles_tanque_corte (
  id               uuid primary key default gen_random_uuid(),
  corte_id         uuid not null,
  sucursal_id      uuid not null,
  tanque_id        uuid not null,
  nivel_medido_gal numeric(12,2) not null check (nivel_medido_gal >= 0),
  creado_en        timestamptz not null default now(),
  foreign key (corte_id, sucursal_id)  references public.cortes (id, sucursal_id),
  foreign key (tanque_id, sucursal_id) references public.tanques (id, sucursal_id),
  unique (corte_id, tanque_id)
);

create table public.vaciados_tanque (
  id                  uuid primary key default gen_random_uuid(),
  corte_id            uuid not null,
  sucursal_id         uuid not null,
  tanque_id           uuid not null,
  motivo              public.motivo_vaciado not null,
  combustible_erroneo public.combustible,
  galones_erroneos    numeric(12,2),
  nivel_medido_gal    numeric(12,2) not null check (nivel_medido_gal > 0),
  nota                text not null check (length(btrim(nota)) >= 3),
  registrado_por      uuid not null references public.perfiles (id),
  creado_en           timestamptz not null default now(),
  foreign key (corte_id, sucursal_id)  references public.cortes (id, sucursal_id),
  foreign key (tanque_id, sucursal_id) references public.tanques (id, sucursal_id),
  constraint vaciados_motivo_ck check (
    (motivo = 'descarga_erronea'
       and combustible_erroneo is not null and galones_erroneos is not null
       and galones_erroneos > 0 and galones_erroneos <= nivel_medido_gal)
    or
    (motivo = 'otra_contaminacion_mantenimiento'
       and combustible_erroneo is null and galones_erroneos is null)
  )
);

create table public.compras_combustible (
  id          uuid primary key default gen_random_uuid(),
  corte_id    uuid not null,
  sucursal_id uuid not null,
  tanque_id   uuid not null,
  galones     numeric(12,2) not null check (galones > 0),
  proveedor   text check (proveedor is null or length(btrim(proveedor)) between 1 and 80),
  origen      public.origen_linea not null default 'manual',
  vaciado_id  uuid references public.vaciados_tanque (id),
  creado_por  uuid not null references public.perfiles (id),
  creado_en   timestamptz not null default now(),
  foreign key (corte_id, sucursal_id)  references public.cortes (id, sucursal_id),
  foreign key (tanque_id, sucursal_id) references public.tanques (id, sucursal_id),
  check ((origen = 'manual') = (vaciado_id is null))
);

create table public.perdidas_combustible (
  id          uuid primary key default gen_random_uuid(),
  corte_id    uuid not null,
  sucursal_id uuid not null,
  tanque_id   uuid not null,
  tipo        public.tipo_perdida not null,
  galones     numeric(12,2) not null check (galones > 0),
  bomba_id    uuid,
  nota        text not null check (length(btrim(nota)) >= 3),
  origen      public.origen_linea not null default 'manual',
  vaciado_id  uuid references public.vaciados_tanque (id),
  creado_por  uuid not null references public.perfiles (id),
  creado_en   timestamptz not null default now(),
  foreign key (corte_id, sucursal_id)  references public.cortes (id, sucursal_id),
  foreign key (tanque_id, sucursal_id) references public.tanques (id, sucursal_id),
  foreign key (bomba_id, sucursal_id)  references public.bombas (id, sucursal_id),
  check ((origen = 'manual') = (vaciado_id is null)),
  check (tipo <> 'contaminacion' or origen = 'vaciado')
);

create table public.ajustes_lectura (
  id                 uuid primary key default gen_random_uuid(),
  corte_id           uuid not null,
  sucursal_id        uuid not null,
  manguera_id        uuid not null,
  valor_correcto_gal numeric(12,2) not null check (valor_correcto_gal >= 0),
  motivo             text not null check (length(btrim(motivo)) >= 3),
  ajustado_por       uuid not null references public.perfiles (id),
  creado_en          timestamptz not null default now(),
  foreign key (corte_id, sucursal_id)    references public.cortes (id, sucursal_id),
  foreign key (manguera_id, sucursal_id) references public.mangueras (id, sucursal_id)
);

create table public.precios (
  id            uuid primary key default gen_random_uuid(),
  sucursal_id   uuid not null references public.sucursales (id),
  combustible   public.combustible not null,
  precio_gal    numeric(8,2) not null check (precio_gal > 0),
  vigente_desde timestamptz not null default now(),
  creado_por    uuid not null references public.perfiles (id),
  creado_en     timestamptz not null default now(),
  unique (sucursal_id, combustible, vigente_desde)
);

create table public.precios_corte (
  corte_id    uuid not null,
  sucursal_id uuid not null,
  combustible public.combustible not null,
  precio_gal  numeric(8,2) not null check (precio_gal > 0),
  primary key (corte_id, combustible),
  foreign key (corte_id, sucursal_id) references public.cortes (id, sucursal_id)
);

-- Índices de apoyo (consultas por corte, sucursal y tanque)
create index lecturas_manguera_corte_idx on public.lecturas_manguera (corte_id);
create index compras_corte_idx           on public.compras_combustible (corte_id);
create index compras_tanque_idx          on public.compras_combustible (tanque_id);
create index perdidas_corte_idx          on public.perdidas_combustible (corte_id);
create index perdidas_tanque_idx         on public.perdidas_combustible (tanque_id);
create index perdidas_sucursal_idx       on public.perdidas_combustible (sucursal_id, creado_en desc);
create index vaciados_tanque_idx         on public.vaciados_tanque (tanque_id, creado_en desc);
create index niveles_tanque_idx          on public.niveles_tanque_corte (tanque_id);
create index precios_vigencia_idx        on public.precios (sucursal_id, combustible, vigente_desde desc);
create index ajustes_corte_idx           on public.ajustes_lectura (corte_id, manguera_id, creado_en desc);
