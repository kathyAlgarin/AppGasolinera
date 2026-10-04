-- 05 · Disparadores: nada se borra, lo cerrado no se modifica, reglas de perfiles y empleados
-- Ver docs/BASE_DE_DATOS.md (secciones 1 y 3)

-- 1) Nada se borra
create function public.prohibir_borrado()
returns trigger language plpgsql set search_path = ''
as $$
begin
  raise exception 'No se permite borrar registros de "%": desactívalos o anúlalos.', tg_table_name;
end $$;

do $$
declare t text;
begin
  foreach t in array array[
    'sucursales','perfiles','tanques','bombas','mangueras','cortes','ajustes_lectura','precios',
    'articulos','inventario_sucursal','sesiones_caja','contadores_ticket','ventas','venta_lineas',
    'empleados','turnos'
  ] loop
    execute format(
      'create trigger %I before delete on public.%I for each row execute function public.prohibir_borrado()',
      t || '_no_borrar', t);
  end loop;
end $$;

-- 2) Registros inmutables una vez insertados
create function public.solo_insertar()
returns trigger language plpgsql set search_path = ''
as $$
begin
  raise exception 'Este registro es inmutable: no se puede modificar ni borrar.';
end $$;

create trigger ajustes_lectura_inmutable before update or delete on public.ajustes_lectura
  for each row execute function public.solo_insertar();
create trigger precios_inmutable before update or delete on public.precios
  for each row execute function public.solo_insertar();
create trigger venta_lineas_inmutable before update or delete on public.venta_lineas
  for each row execute function public.solo_insertar();

-- 3) Las líneas de un corte solo se tocan mientras el corte está en curso
create function public.bloquear_si_corte_cerrado()
returns trigger language plpgsql set search_path = ''
as $$
declare v_estado public.estado_corte;
begin
  if tg_op in ('UPDATE', 'DELETE') then
    select estado into v_estado from public.cortes where id = old.corte_id;
    if v_estado is distinct from 'en_curso' then
      raise exception 'El corte ya está cerrado: no se puede modificar.';
    end if;
  end if;
  if tg_op in ('INSERT', 'UPDATE') then
    select estado into v_estado from public.cortes where id = new.corte_id;
    if v_estado is distinct from 'en_curso' then
      raise exception 'El corte ya está cerrado: no se puede modificar.';
    end if;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array[
    'lecturas_manguera','cambios_medidor','niveles_tanque_corte','compras_combustible',
    'perdidas_combustible','vaciados_tanque','entradas_inventario','bajas_inventario','precios_corte'
  ] loop
    execute format(
      'create trigger %I before insert or update or delete on public.%I for each row execute function public.bloquear_si_corte_cerrado()',
      t || '_corte_cerrado', t);
  end loop;
end $$;

-- 4) Un corte cerrado es inmutable
create function public.cortes_proteger()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if old.estado = 'cerrado' then
    raise exception 'Un corte cerrado no se puede modificar.';
  end if;
  if new.sucursal_id <> old.sucursal_id or new.secuencia <> old.secuencia then
    raise exception 'No se puede cambiar la sucursal ni la secuencia de un corte.';
  end if;
  return new;
end $$;
create trigger cortes_inmutable before update on public.cortes
  for each row execute function public.cortes_proteger();

-- 5) Ventas: solo pasan de "completada" a "anulada"; nada más cambia
create function public.ventas_proteger()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if old.estado = 'anulada' then
    raise exception 'La venta ya está anulada.';
  end if;
  if new.estado <> 'anulada' then
    raise exception 'Una venta solo puede anularse.';
  end if;
  if (new.id, new.sucursal_id, new.sesion_caja_id, new.corte_id, new.cajero_id, new.numero,
      new.total_usd, new.metodo_pago, new.recibido_usd, new.vuelto_usd, new.creado_en)
     is distinct from
     (old.id, old.sucursal_id, old.sesion_caja_id, old.corte_id, old.cajero_id, old.numero,
      old.total_usd, old.metodo_pago, old.recibido_usd, old.vuelto_usd, old.creado_en) then
    raise exception 'Solo se puede anular una venta; sus datos no se modifican.';
  end if;
  return new;
end $$;
create trigger ventas_inmutable before update on public.ventas
  for each row execute function public.ventas_proteger();

-- 6) Sesiones de caja: una caja cerrada es inmutable y sus datos de apertura no cambian
create function public.sesiones_proteger()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if old.cerrada_en is not null then
    raise exception 'La caja ya está cerrada: no se puede modificar.';
  end if;
  if (new.id, new.sucursal_id, new.cajero_id, new.corte_id, new.fondo_inicial_usd, new.abierta_en)
     is distinct from
     (old.id, old.sucursal_id, old.cajero_id, old.corte_id, old.fondo_inicial_usd, old.abierta_en) then
    raise exception 'Los datos de apertura de la caja no se pueden modificar.';
  end if;
  return new;
end $$;
create trigger sesiones_inmutable before update on public.sesiones_caja
  for each row execute function public.sesiones_proteger();

-- 7) Perfiles: cajeros solo en sucursales con tienda; no quedarse sin Gerente General
create function public.perfiles_validar()
returns trigger language plpgsql set search_path = ''
as $$
declare v_tienda boolean;
begin
  if new.rol = 'cajero' then
    select tiene_tienda into v_tienda from public.sucursales where id = new.sucursal_id;
    if not coalesce(v_tienda, false) then
      raise exception 'Solo se pueden crear cajeros en sucursales con tienda.';
    end if;
  end if;

  if tg_op = 'UPDATE' then
    if new.id <> old.id then
      raise exception 'No se puede cambiar el identificador de un perfil.';
    end if;
    if auth.uid() is not null and auth.uid() = old.id and old.activo and not new.activo then
      raise exception 'No puedes desactivarte a ti mismo.';
    end if;
    if old.rol = 'gerente_general' and old.activo
       and (not new.activo or new.rol <> 'gerente_general') then
      if not exists (
        select 1 from public.perfiles p
        where p.rol = 'gerente_general' and p.activo and p.id <> old.id
      ) then
        raise exception 'No se puede desactivar al último Gerente General activo.';
      end if;
    end if;
  end if;
  return new;
end $$;
create trigger perfiles_validar_ck before insert or update on public.perfiles
  for each row execute function public.perfiles_validar();

-- 8) Empleados: el perfil vinculado debe ser un cajero de la misma sucursal
create function public.empleados_validar()
returns trigger language plpgsql set search_path = ''
as $$
declare p public.perfiles;
begin
  if new.perfil_id is not null then
    select * into p from public.perfiles where id = new.perfil_id;
    if not found or p.rol <> 'cajero' or p.sucursal_id <> new.sucursal_id then
      raise exception 'El usuario vinculado debe ser un cajero de la misma sucursal.';
    end if;
    if new.cargo <> 'cajero' then
      raise exception 'Solo un empleado con cargo Cajero puede vincularse a un usuario.';
    end if;
  end if;
  if tg_op = 'UPDATE' and new.sucursal_id <> old.sucursal_id then
    raise exception 'Un empleado no cambia de sucursal.';
  end if;
  return new;
end $$;
create trigger empleados_validar_ck before insert or update on public.empleados
  for each row execute function public.empleados_validar();

-- 9) Artículos: el tipo no cambia; al crear un producto se abre su inventario en las sucursales con tienda
create function public.articulos_proteger()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if new.tipo <> old.tipo or new.categoria <> old.categoria then
    raise exception 'El tipo y la categoría de un artículo no se pueden cambiar; crea uno nuevo.';
  end if;
  return new;
end $$;
create trigger articulos_inmutable_tipo before update on public.articulos
  for each row execute function public.articulos_proteger();

create function public.articulos_crear_inventario()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  if new.tipo = 'producto' then
    insert into public.inventario_sucursal (sucursal_id, articulo_id)
    select s.id, new.id from public.sucursales s where s.tiene_tienda
    on conflict do nothing;
  end if;
  return new;
end $$;
create trigger articulos_inventario after insert on public.articulos
  for each row execute function public.articulos_crear_inventario();
