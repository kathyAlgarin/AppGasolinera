-- 01 · Tipos enumerados y configuración del sistema
-- Ver docs/BASE_DE_DATOS.md (secciones 2 y 3.1)

create type public.rol_usuario        as enum ('gerente_general', 'gerente_sucursal', 'cajero');
create type public.combustible        as enum ('super', 'regular', 'diesel');
create type public.estado_corte       as enum ('en_curso', 'cerrado');
create type public.tipo_corte         as enum ('matutino', 'vespertino');
create type public.tipo_perdida       as enum ('merma', 'fuga', 'falla_tecnica', 'derrame', 'contaminacion');
create type public.origen_linea       as enum ('manual', 'vaciado');
create type public.motivo_vaciado     as enum ('descarga_erronea', 'otra_contaminacion_mantenimiento');
create type public.tipo_articulo      as enum ('producto', 'servicio');
create type public.categoria_articulo as enum ('lubricantes', 'bebidas', 'snacks', 'otros_productos', 'servicios');
create type public.motivo_baja        as enum ('vencido', 'danado', 'otro');
create type public.metodo_pago        as enum ('efectivo', 'tarjeta');
create type public.estado_venta       as enum ('completada', 'anulada');
create type public.cargo_empleado     as enum ('despachador', 'cajero', 'supervisor', 'mantenimiento', 'otro');

create table public.configuracion (
  clave       text primary key,
  valor       numeric not null,
  descripcion text not null
);

insert into public.configuracion (clave, valor, descripcion) values
  ('tanque_critico_pct',     20,  'Estado Crítico del tanque por porcentaje (<=)'),
  ('tanque_medio_pct',       50,  'Estado Medio del tanque por porcentaje (<=)'),
  ('autonomia_critica_dias', 2,   'Estado Crítico por autonomía en días (<)'),
  ('autonomia_media_dias',   5,   'Estado Medio por autonomía en días (<)'),
  ('autonomia_ventana_dias', 7,   'Días de historial para el promedio diario de venta'),
  ('tolerancia_cuadre_pct',  0.5, 'Porcentaje de los galones despachados bajo el cual la diferencia del cuadre se considera "cuadra"');

-- Lectura de configuración (security definer: la pueden usar las vistas con cualquier rol)
create function public.cfg(p_clave text)
returns numeric
language sql stable security definer set search_path = ''
as $$ select valor from public.configuracion where clave = p_clave $$;
