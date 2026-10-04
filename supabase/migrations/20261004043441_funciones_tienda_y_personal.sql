-- 08 · Funciones del servidor: tienda, cajas, ventas y personal
-- Ver docs/BASE_DE_DATOS.md (sección 5)

create function public._validar_cantidad(p_valor integer, p_campo text default 'La cantidad')
returns void
language plpgsql immutable set search_path = ''
as $$
begin
  if p_valor is null or p_valor <= 0 then
    raise exception '% debe ser un número entero mayor que 0.', p_campo;
  end if;
end $$;

-- Perfil del cajero que llama (activo, con tienda activa en su sucursal)
create function public._cajero_actual()
returns public.perfiles
language plpgsql security definer set search_path = ''
as $$
declare
  p public.perfiles;
  s public.sucursales;
begin
  select * into p from public.perfiles where id = auth.uid() and activo and rol = 'cajero';
  if not found then
    raise exception 'Solo un cajero puede hacer esto.' using errcode = '42501';
  end if;
  select * into s from public.sucursales where id = p.sucursal_id;
  if not (s.activa and s.tiene_tienda) then
    raise exception 'Tu sucursal no tiene la tienda activa.';
  end if;
  return p;
end $$;

-- ───────────── Inventario (Gerente de Sucursal) ─────────────
create function public.registrar_entrada(
  p_corte uuid, p_articulo uuid, p_cantidad integer, p_proveedor text default null)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  c public.cortes;
  v_id uuid;
begin
  c := public._corte_editable(p_corte);
  if not (select tiene_tienda from public.sucursales where id = c.sucursal_id) then
    raise exception 'La sucursal no tiene tienda.';
  end if;
  perform public._validar_cantidad(p_cantidad);
  if not exists (select 1 from public.articulos where id = p_articulo and tipo = 'producto' and activo) then
    raise exception 'El artículo no existe, está inactivo o es un servicio.';
  end if;
  update public.inventario_sucursal set stock = stock + p_cantidad
   where sucursal_id = c.sucursal_id and articulo_id = p_articulo;
  if not found then raise exception 'El artículo no está en el inventario de la sucursal.'; end if;

  insert into public.entradas_inventario (corte_id, sucursal_id, articulo_id, cantidad, proveedor, creado_por)
  values (p_corte, c.sucursal_id, p_articulo, p_cantidad, nullif(btrim(p_proveedor), ''), auth.uid())
  returning id into v_id;
  return v_id;
end $$;

create function public.eliminar_entrada(p_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare e public.entradas_inventario;
begin
  select * into e from public.entradas_inventario where id = p_id;
  if not found then raise exception 'No se encontró la entrada.'; end if;
  perform public._corte_editable(e.corte_id);
  update public.inventario_sucursal set stock = stock - e.cantidad
   where sucursal_id = e.sucursal_id and articulo_id = e.articulo_id and stock >= e.cantidad;
  if not found then
    raise exception 'No se puede eliminar: ya se vendió parte de esa mercadería.';
  end if;
  delete from public.entradas_inventario where id = p_id;
end $$;

create function public.registrar_baja(
  p_corte uuid, p_articulo uuid, p_cantidad integer, p_motivo public.motivo_baja, p_nota text default null)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  c public.cortes;
  v_id uuid;
begin
  c := public._corte_editable(p_corte);
  if not (select tiene_tienda from public.sucursales where id = c.sucursal_id) then
    raise exception 'La sucursal no tiene tienda.';
  end if;
  perform public._validar_cantidad(p_cantidad);
  if p_motivo = 'otro' and (p_nota is null or length(btrim(p_nota)) < 3) then
    raise exception 'La nota es obligatoria cuando el motivo es "otro".';
  end if;
  update public.inventario_sucursal set stock = stock - p_cantidad
   where sucursal_id = c.sucursal_id and articulo_id = p_articulo and stock >= p_cantidad;
  if not found then raise exception 'La cantidad supera el stock disponible.'; end if;

  insert into public.bajas_inventario (corte_id, sucursal_id, articulo_id, cantidad, motivo, nota, creado_por)
  values (p_corte, c.sucursal_id, p_articulo, p_cantidad, p_motivo, nullif(btrim(p_nota), ''), auth.uid())
  returning id into v_id;
  return v_id;
end $$;

create function public.eliminar_baja(p_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare b public.bajas_inventario;
begin
  select * into b from public.bajas_inventario where id = p_id;
  if not found then raise exception 'No se encontró la baja.'; end if;
  perform public._corte_editable(b.corte_id);
  update public.inventario_sucursal set stock = stock + b.cantidad
   where sucursal_id = b.sucursal_id and articulo_id = b.articulo_id;
  delete from public.bajas_inventario where id = p_id;
end $$;

-- ───────────── Caja y ventas ─────────────
create function public.abrir_caja(p_fondo numeric)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  p public.perfiles;
  c public.cortes;
  v_id uuid;
begin
  p := public._cajero_actual();
  if p_fondo is null or p_fondo < 0 or p_fondo <> round(p_fondo, 2) then
    raise exception 'El fondo inicial debe ser un número mayor o igual a 0 con máximo 2 decimales.';
  end if;
  select * into c from public.cortes where sucursal_id = p.sucursal_id and estado = 'en_curso' for share;
  if not found then
    raise exception 'No hay un corte en curso; intenta de nuevo en un momento.';
  end if;
  begin
    insert into public.sesiones_caja (sucursal_id, cajero_id, corte_id, fondo_inicial_usd)
    values (p.sucursal_id, p.id, c.id, p_fondo)
    returning id into v_id;
  exception when unique_violation then
    raise exception 'Ya tienes una caja abierta.';
  end;
  return v_id;
end $$;

create function public.registrar_venta(
  p_sesion uuid, p_metodo public.metodo_pago, p_recibido numeric, p_lineas jsonb)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  p public.perfiles;
  ses public.sesiones_caja;
  a public.articulos;
  r record;
  v_total numeric := 0;
  v_vuelto numeric;
  v_recibido numeric;
  v_num bigint;
  v_venta uuid;
  v_stock integer;
begin
  p := public._cajero_actual();
  select * into ses from public.sesiones_caja where id = p_sesion for update;
  if not found or ses.cajero_id <> p.id then
    raise exception 'Esa caja no es tuya.' using errcode = '42501';
  end if;
  if ses.cerrada_en is not null then raise exception 'La caja ya está cerrada.'; end if;

  if jsonb_typeof(p_lineas) <> 'array' or jsonb_array_length(p_lineas) = 0 or jsonb_array_length(p_lineas) > 50 then
    raise exception 'La venta necesita entre 1 y 50 líneas.';
  end if;
  if exists (
    select 1 from jsonb_array_elements(p_lineas) x
    where (x ->> 'articulo_id') is null or coalesce((x ->> 'cantidad')::integer, 0) <= 0
  ) then
    raise exception 'Cada línea necesita un artículo y una cantidad entera mayor que 0.';
  end if;

  -- Pasada 1: validar stock y calcular el total con los precios del catálogo
  for r in
    select (x ->> 'articulo_id')::uuid as articulo_id, sum((x ->> 'cantidad')::integer)::integer as cantidad
    from jsonb_array_elements(p_lineas) x group by 1
  loop
    select * into a from public.articulos where id = r.articulo_id and activo;
    if not found then raise exception 'Hay un artículo que no está disponible.'; end if;
    if a.tipo = 'producto' then
      select stock into v_stock from public.inventario_sucursal
       where sucursal_id = ses.sucursal_id and articulo_id = a.id for update;
      if v_stock is null or v_stock < r.cantidad then
        raise exception 'Stock insuficiente de "%": disponible %.', a.nombre, coalesce(v_stock, 0);
      end if;
    end if;
    v_total := v_total + round(r.cantidad * a.precio_usd, 2);
  end loop;

  if p_metodo = 'efectivo' then
    if p_recibido is null or p_recibido <> round(p_recibido, 2) or p_recibido < v_total then
      raise exception 'El monto recibido (%) es menor que el total (%).', coalesce(p_recibido, 0), v_total;
    end if;
    v_recibido := p_recibido;
    v_vuelto := p_recibido - v_total;
  end if;

  update public.contadores_ticket set ultimo = ultimo + 1
   where sucursal_id = ses.sucursal_id returning ultimo into v_num;

  insert into public.ventas
    (sucursal_id, sesion_caja_id, corte_id, cajero_id, numero, total_usd, metodo_pago, recibido_usd, vuelto_usd)
  values (ses.sucursal_id, ses.id, ses.corte_id, p.id, v_num, v_total, p_metodo, v_recibido, v_vuelto)
  returning id into v_venta;

  -- Pasada 2: líneas y descuento de stock
  for r in
    select (x ->> 'articulo_id')::uuid as articulo_id, sum((x ->> 'cantidad')::integer)::integer as cantidad
    from jsonb_array_elements(p_lineas) x group by 1
  loop
    select * into a from public.articulos where id = r.articulo_id;
    insert into public.venta_lineas (venta_id, sucursal_id, articulo_id, cantidad, precio_unitario_usd, subtotal_usd)
    values (v_venta, ses.sucursal_id, a.id, r.cantidad, a.precio_usd, round(r.cantidad * a.precio_usd, 2));
    if a.tipo = 'producto' then
      update public.inventario_sucursal set stock = stock - r.cantidad
       where sucursal_id = ses.sucursal_id and articulo_id = a.id;
    end if;
  end loop;

  return jsonb_build_object('venta_id', v_venta, 'numero', v_num, 'total_usd', v_total,
                            'recibido_usd', v_recibido, 'vuelto_usd', v_vuelto);
end $$;

create function public.anular_venta(p_venta uuid, p_motivo text)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v public.ventas;
  ses public.sesiones_caja;
  v_sesion uuid;
  l record;
begin
  select sesion_caja_id into v_sesion from public.ventas where id = p_venta;
  if not found then raise exception 'No se encontró la venta.'; end if;
  select * into ses from public.sesiones_caja where id = v_sesion for update;
  select * into v from public.ventas where id = p_venta for update;

  perform public._exigir_gerente_sucursal(v.sucursal_id);
  if v.estado <> 'completada' then raise exception 'La venta ya está anulada.'; end if;
  if ses.cerrada_en is not null then
    raise exception 'La caja de esta venta ya se cerró: la venta es definitiva.';
  end if;
  if p_motivo is null or length(btrim(p_motivo)) < 3 then
    raise exception 'El motivo es obligatorio.';
  end if;

  for l in
    select vl.articulo_id, vl.cantidad
    from public.venta_lineas vl
    join public.articulos a on a.id = vl.articulo_id and a.tipo = 'producto'
    where vl.venta_id = v.id
  loop
    update public.inventario_sucursal set stock = stock + l.cantidad
     where sucursal_id = v.sucursal_id and articulo_id = l.articulo_id;
  end loop;

  update public.ventas
     set estado = 'anulada', anulada_por = auth.uid(), anulada_en = now(), motivo_anulacion = btrim(p_motivo)
   where id = v.id;
end $$;

create function public.cerrar_caja(p_sesion uuid, p_contado numeric)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  p public.perfiles;
  ses public.sesiones_caja;
  v_ef numeric;
  v_esp numeric;
begin
  select * into p from public.perfiles where id = auth.uid() and activo and rol = 'cajero';
  if not found then raise exception 'Solo un cajero puede cerrar su caja.' using errcode = '42501'; end if;
  select * into ses from public.sesiones_caja where id = p_sesion for update;
  if not found or ses.cajero_id <> p.id then
    raise exception 'Esa caja no es tuya.' using errcode = '42501';
  end if;
  if ses.cerrada_en is not null then raise exception 'La caja ya está cerrada.'; end if;
  if p_contado is null or p_contado < 0 or p_contado <> round(p_contado, 2) then
    raise exception 'El efectivo contado debe ser un número mayor o igual a 0 con máximo 2 decimales.';
  end if;

  select coalesce(sum(total_usd), 0) into v_ef from public.ventas
   where sesion_caja_id = ses.id and estado = 'completada' and metodo_pago = 'efectivo';
  v_esp := ses.fondo_inicial_usd + v_ef;

  update public.sesiones_caja
     set cerrada_en = now(), efectivo_contado_usd = p_contado, efectivo_esperado_usd = v_esp,
         diferencia_usd = p_contado - v_esp, cerrada_por = p.id
   where id = ses.id;

  return jsonb_build_object('esperado_usd', v_esp, 'contado_usd', p_contado, 'diferencia_usd', p_contado - v_esp);
end $$;

create function public.cerrar_caja_forzado(p_sesion uuid, p_contado numeric, p_motivo text)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  ses public.sesiones_caja;
  v_ef numeric;
  v_esp numeric;
begin
  select * into ses from public.sesiones_caja where id = p_sesion for update;
  if not found then raise exception 'No se encontró la caja.'; end if;
  perform public._exigir_gerente_sucursal(ses.sucursal_id);
  if ses.cerrada_en is not null then raise exception 'La caja ya está cerrada.'; end if;
  if p_contado is null or p_contado < 0 or p_contado <> round(p_contado, 2) then
    raise exception 'El efectivo contado debe ser un número mayor o igual a 0 con máximo 2 decimales.';
  end if;
  if p_motivo is null or length(btrim(p_motivo)) < 3 then
    raise exception 'El motivo del cierre forzado es obligatorio.';
  end if;

  select coalesce(sum(total_usd), 0) into v_ef from public.ventas
   where sesion_caja_id = ses.id and estado = 'completada' and metodo_pago = 'efectivo';
  v_esp := ses.fondo_inicial_usd + v_ef;

  update public.sesiones_caja
     set cerrada_en = now(), efectivo_contado_usd = p_contado, efectivo_esperado_usd = v_esp,
         diferencia_usd = p_contado - v_esp, cierre_forzado = true,
         motivo_cierre_forzado = btrim(p_motivo), cerrada_por = auth.uid()
   where id = ses.id;

  return jsonb_build_object('esperado_usd', v_esp, 'contado_usd', p_contado, 'diferencia_usd', p_contado - v_esp);
end $$;

-- ───────────── Personal: quién trabaja ahora ─────────────
create function public.empleados_en_turno(p_sucursal uuid, p_momento timestamptz default now())
returns table (
  empleado_id uuid, nombre text, cargo public.cargo_empleado,
  turno_id uuid, turno_nombre text, hora_inicio time, hora_fin time)
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_t time := (p_momento at time zone 'America/El_Salvador')::time;
  v_dow integer := extract(isodow from (p_momento at time zone 'America/El_Salvador'))::integer;
  v_prev integer := ((extract(isodow from (p_momento at time zone 'America/El_Salvador'))::integer + 5) % 7) + 1;
begin
  if not (
    public.es_gerente_general()
    or exists (select 1 from public.perfiles p
                where p.id = auth.uid() and p.activo and p.rol = 'gerente_sucursal'
                  and p.sucursal_id = p_sucursal)
  ) then
    raise exception 'No tienes permiso para consultar esta sucursal.' using errcode = '42501';
  end if;

  return query
  select e.id, e.nombre, e.cargo, t.id, t.nombre, t.hora_inicio, t.hora_fin
  from public.empleados e
  join public.asignaciones_turno a on a.empleado_id = e.id
  join public.turnos t on t.id = a.turno_id
  where e.sucursal_id = p_sucursal and e.activo and t.activo
    and (
      (t.hora_inicio < t.hora_fin and v_t >= t.hora_inicio and v_t < t.hora_fin and v_dow = any (a.dias))
      or
      (t.hora_inicio > t.hora_fin and (
          (v_t >= t.hora_inicio and v_dow = any (a.dias))
          or (v_t < t.hora_fin and v_prev = any (a.dias))))
    )
  order by t.hora_inicio, e.nombre;
end $$;
