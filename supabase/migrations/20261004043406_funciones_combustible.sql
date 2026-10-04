-- 07 · Funciones del servidor: acceso, sucursales, precios y combustible
-- Ver docs/BASE_DE_DATOS.md (sección 5). Todas verifican rol y sucursal de quien llama.

-- ───────────── Utilidades de acceso ─────────────
create function public.mi_rol()
returns public.rol_usuario
language sql stable security definer set search_path = ''
as $$ select rol from public.perfiles where id = auth.uid() and activo $$;

create function public.mi_sucursal()
returns uuid
language sql stable security definer set search_path = ''
as $$ select sucursal_id from public.perfiles where id = auth.uid() and activo $$;

create function public.es_gerente_general()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select coalesce((select rol = 'gerente_general' from public.perfiles where id = auth.uid() and activo), false)
$$;

create function public._exigir_gerente_general()
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if not public.es_gerente_general() then
    raise exception 'Solo el Gerente General puede hacer esto.' using errcode = '42501';
  end if;
end $$;

create function public._exigir_gerente_sucursal(p_sucursal uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.perfiles p
    join public.sucursales s on s.id = p.sucursal_id
    where p.id = auth.uid() and p.activo and p.rol = 'gerente_sucursal'
      and p.sucursal_id = p_sucursal and s.activa
  ) then
    raise exception 'Solo el Gerente de esta sucursal puede hacer esto.' using errcode = '42501';
  end if;
end $$;

-- Corte en curso, con bloqueo compartido, verificando que quien llama es el gerente de su sucursal
create function public._corte_editable(p_corte uuid)
returns public.cortes
language plpgsql security definer set search_path = ''
as $$
declare c public.cortes;
begin
  select * into c from public.cortes where id = p_corte for share;
  if not found then
    raise exception 'No se encontró el corte.';
  end if;
  perform public._exigir_gerente_sucursal(c.sucursal_id);
  if c.estado <> 'en_curso' then
    raise exception 'El corte ya está cerrado: no se puede modificar.';
  end if;
  return c;
end $$;

create function public._validar_galones(p_valor numeric, p_campo text default 'Los galones')
returns void
language plpgsql immutable set search_path = ''
as $$
begin
  if p_valor is null or p_valor <= 0 or p_valor <> round(p_valor, 2) then
    raise exception '% deben ser un número mayor que 0 con máximo 2 decimales.', p_campo;
  end if;
end $$;

create function public._nivel_estimado(p_tanque uuid)
returns numeric
language sql stable security definer set search_path = ''
as $$ select nivel_estimado_gal from public.v_nivel_tanque_estimado where tanque_id = p_tanque $$;

create function public._lectura_final_efectiva(p_corte uuid, p_manguera uuid)
returns numeric
language sql stable security definer set search_path = ''
as $$
  select coalesce(
    (select a.valor_correcto_gal from public.ajustes_lectura a
      where a.corte_id = p_corte and a.manguera_id = p_manguera
      order by a.creado_en desc limit 1),
    (select l.lectura_final_gal from public.lecturas_manguera l
      where l.corte_id = p_corte and l.manguera_id = p_manguera))
$$;

create function public._lectura_inicial(p_corte uuid, p_manguera uuid)
returns numeric
language sql stable security definer set search_path = ''
as $$
  select case when c.secuencia = 1 then
      (select l.lectura_inicial_manual_gal from public.lecturas_manguera l
        where l.corte_id = c.id and l.manguera_id = p_manguera)
    else
      (select public._lectura_final_efectiva(pc.id, p_manguera) from public.cortes pc
        where pc.sucursal_id = c.sucursal_id and pc.secuencia = c.secuencia - 1)
    end
  from public.cortes c where c.id = p_corte
$$;

create function public.marcar_password_cambiada()
returns void
language sql security definer set search_path = ''
as $$ update public.perfiles set debe_cambiar_password = false where id = auth.uid() $$;

-- ───────────── Sucursales (Gerente General) ─────────────
create function public.crear_sucursal(
  p_nombre text, p_direccion text, p_tiene_tienda boolean, p_tanques jsonb)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_id uuid;
  v_t jsonb;
  v_comb public.combustible;
  v_cap numeric;
  v_niv numeric;
  v_vistos public.combustible[] := '{}';
  v_bomba uuid;
  i integer;
  c public.combustible;
begin
  perform public._exigir_gerente_general();

  if jsonb_typeof(p_tanques) <> 'array' or jsonb_array_length(p_tanques) <> 3 then
    raise exception 'Se requieren exactamente 3 tanques (Súper, Regular y Diésel).';
  end if;

  insert into public.sucursales (nombre, direccion, tiene_tienda)
  values (btrim(p_nombre), btrim(p_direccion), coalesce(p_tiene_tienda, false))
  returning id into v_id;

  for v_t in select * from jsonb_array_elements(p_tanques) loop
    v_comb := (v_t ->> 'combustible')::public.combustible;
    if v_comb = any (v_vistos) then
      raise exception 'Cada combustible debe aparecer una sola vez.';
    end if;
    v_vistos := v_vistos || v_comb;

    v_cap := (v_t ->> 'capacidad_gal')::numeric;
    v_niv := (v_t ->> 'nivel_inicial_gal')::numeric;
    if v_cap is null or v_cap <= 0 or v_cap <> round(v_cap, 2) then
      raise exception 'La capacidad del tanque debe ser un número mayor que 0 con máximo 2 decimales.';
    end if;
    if v_niv is null or v_niv < 0 or v_niv <> round(v_niv, 2) then
      raise exception 'El nivel inicial debe ser un número mayor o igual a 0 con máximo 2 decimales.';
    end if;
    if v_niv > v_cap then
      raise exception 'El nivel inicial no puede superar la capacidad del tanque.';
    end if;

    insert into public.tanques (sucursal_id, combustible, capacidad_gal, nivel_inicial_gal)
    values (v_id, v_comb, v_cap, v_niv);
  end loop;

  -- 6 bombas, cada una con 3 mangueras (18 en total)
  for i in 1..6 loop
    insert into public.bombas (sucursal_id, numero) values (v_id, i) returning id into v_bomba;
    foreach c in array enum_range(null::public.combustible) loop
      insert into public.mangueras (bomba_id, sucursal_id, combustible) values (v_bomba, v_id, c);
    end loop;
  end loop;

  -- Primer corte en curso y contador de tickets
  insert into public.cortes (sucursal_id, secuencia) values (v_id, 1);
  insert into public.contadores_ticket (sucursal_id) values (v_id);

  if coalesce(p_tiene_tienda, false) then
    insert into public.inventario_sucursal (sucursal_id, articulo_id)
    select v_id, a.id from public.articulos a where a.tipo = 'producto' and a.activo;
  end if;

  return v_id;
end $$;

create function public.editar_sucursal(p_id uuid, p_nombre text, p_direccion text)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  perform public._exigir_gerente_general();
  update public.sucursales
     set nombre = btrim(p_nombre), direccion = btrim(p_direccion)
   where id = p_id;
  if not found then raise exception 'No se encontró la sucursal.'; end if;
end $$;

create function public.cambiar_estado_sucursal(p_id uuid, p_activa boolean)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  perform public._exigir_gerente_general();
  update public.sucursales set activa = p_activa where id = p_id;
  if not found then raise exception 'No se encontró la sucursal.'; end if;
end $$;

create function public.configurar_tienda(p_id uuid, p_tiene_tienda boolean)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  perform public._exigir_gerente_general();
  if not exists (select 1 from public.sucursales where id = p_id) then
    raise exception 'No se encontró la sucursal.';
  end if;
  if not p_tiene_tienda and exists (
    select 1 from public.sesiones_caja where sucursal_id = p_id and cerrada_en is null
  ) then
    raise exception 'No se puede desactivar la tienda con cajas abiertas.';
  end if;
  update public.sucursales set tiene_tienda = p_tiene_tienda where id = p_id;
  if p_tiene_tienda then
    insert into public.inventario_sucursal (sucursal_id, articulo_id)
    select p_id, a.id from public.articulos a where a.tipo = 'producto' and a.activo
    on conflict do nothing;
  end if;
end $$;

-- ───────────── Precios (Gerente General) ─────────────
create function public.fijar_precio(
  p_sucursales uuid[], p_combustible public.combustible, p_precio numeric)
returns integer
language plpgsql security definer set search_path = ''
as $$
declare n integer;
begin
  perform public._exigir_gerente_general();
  if p_precio is null or p_precio <= 0 or p_precio <> round(p_precio, 2) then
    raise exception 'El precio debe ser un número mayor que 0 con máximo 2 decimales.';
  end if;
  insert into public.precios (sucursal_id, combustible, precio_gal, creado_por)
  select s.id, p_combustible, p_precio, auth.uid()
  from public.sucursales s
  where s.activa and (p_sucursales is null or s.id = any (p_sucursales));
  get diagnostics n = row_count;
  if n = 0 then raise exception 'No hay sucursales activas a las que aplicar el precio.'; end if;
  return n;
end $$;

-- ───────────── Lecturas (borrador por bomba) ─────────────
create function public.guardar_lecturas_bomba(p_corte uuid, p_bomba uuid, p_lecturas jsonb)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  c public.cortes;
  v_item jsonb;
  v_comb public.combustible;
  v_vistos public.combustible[] := '{}';
  v_man uuid;
  v_fin numeric;
  v_ini numeric;
  v_cm public.cambios_medidor;
  v_num smallint;
begin
  c := public._corte_editable(p_corte);

  select numero into v_num from public.bombas where id = p_bomba and sucursal_id = c.sucursal_id;
  if not found then
    raise exception 'La bomba no pertenece a la sucursal.';
  end if;
  if jsonb_typeof(p_lecturas) <> 'array' or jsonb_array_length(p_lecturas) <> 3 then
    raise exception 'La Bomba % requiere las 3 lecturas (Súper, Regular y Diésel).', v_num;
  end if;

  for v_item in select * from jsonb_array_elements(p_lecturas) loop
    v_comb := (v_item ->> 'combustible')::public.combustible;
    if v_comb = any (v_vistos) then
      raise exception 'Cada combustible debe aparecer una sola vez por bomba.';
    end if;
    v_vistos := v_vistos || v_comb;

    select id into v_man from public.mangueras where bomba_id = p_bomba and combustible = v_comb;
    if not found then raise exception 'La bomba no tiene manguera de %.', v_comb; end if;

    v_fin := (v_item ->> 'lectura_final_gal')::numeric;
    if v_fin is null or v_fin < 0 or v_fin <> round(v_fin, 2) then
      raise exception 'La lectura final (Bomba %, %) debe ser un número mayor o igual a 0 con máximo 2 decimales.', v_num, v_comb;
    end if;

    if c.secuencia = 1 then
      v_ini := (v_item ->> 'lectura_inicial_gal')::numeric;
      if v_ini is null or v_ini < 0 or v_ini <> round(v_ini, 2) then
        raise exception 'En el primer corte hay que capturar la lectura inicial (Bomba %, %).', v_num, v_comb;
      end if;
    else
      v_ini := public._lectura_inicial(p_corte, v_man);
      if v_ini is null then
        raise exception 'No hay lectura inicial para la Bomba %, %.', v_num, v_comb;
      end if;
    end if;

    select * into v_cm from public.cambios_medidor where corte_id = p_corte and manguera_id = v_man;
    if found then
      if v_fin < v_cm.lectura_inicial_nuevo_gal then
        raise exception 'La lectura final (Bomba %, %) no puede ser menor que la inicial del medidor nuevo.', v_num, v_comb;
      end if;
    elsif v_fin < v_ini then
      raise exception 'La lectura final (Bomba %, %) no puede ser menor que la inicial (%).', v_num, v_comb, v_ini;
    end if;

    insert into public.lecturas_manguera
      (corte_id, sucursal_id, manguera_id, lectura_inicial_manual_gal, lectura_final_gal)
    values
      (p_corte, c.sucursal_id, v_man, case when c.secuencia = 1 then v_ini end, v_fin)
    on conflict (corte_id, manguera_id) do update
      set lectura_final_gal = excluded.lectura_final_gal,
          lectura_inicial_manual_gal = excluded.lectura_inicial_manual_gal,
          guardada_en = now();
  end loop;
end $$;

create function public.registrar_cambio_medidor(
  p_corte uuid, p_manguera uuid, p_final_viejo numeric, p_inicial_nuevo numeric, p_nota text)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  c public.cortes;
  v_ini numeric;
  v_fin numeric;
  v_id uuid;
begin
  c := public._corte_editable(p_corte);
  if not exists (select 1 from public.mangueras where id = p_manguera and sucursal_id = c.sucursal_id) then
    raise exception 'La manguera no pertenece a la sucursal.';
  end if;
  if p_final_viejo is null or p_final_viejo < 0 or p_final_viejo <> round(p_final_viejo, 2)
     or p_inicial_nuevo is null or p_inicial_nuevo < 0 or p_inicial_nuevo <> round(p_inicial_nuevo, 2) then
    raise exception 'Las lecturas deben ser números mayores o iguales a 0 con máximo 2 decimales.';
  end if;
  if p_nota is null or length(btrim(p_nota)) < 3 then
    raise exception 'La nota es obligatoria.';
  end if;

  v_ini := public._lectura_inicial(p_corte, p_manguera);
  if v_ini is null then
    raise exception 'Guarda primero las lecturas de esa bomba (falta la lectura inicial).';
  end if;
  if p_final_viejo < v_ini then
    raise exception 'La lectura final del medidor viejo no puede ser menor que la inicial (%).', v_ini;
  end if;

  select lectura_final_gal into v_fin from public.lecturas_manguera
   where corte_id = p_corte and manguera_id = p_manguera;
  if v_fin is not null and v_fin < p_inicial_nuevo then
    raise exception 'La lectura final guardada (%) es menor que la inicial del medidor nuevo.', v_fin;
  end if;

  insert into public.cambios_medidor
    (corte_id, sucursal_id, manguera_id, lectura_final_viejo_gal, lectura_inicial_nuevo_gal, nota, registrado_por)
  values (p_corte, c.sucursal_id, p_manguera, p_final_viejo, p_inicial_nuevo, btrim(p_nota), auth.uid())
  on conflict (corte_id, manguera_id) do update
    set lectura_final_viejo_gal = excluded.lectura_final_viejo_gal,
        lectura_inicial_nuevo_gal = excluded.lectura_inicial_nuevo_gal,
        nota = excluded.nota,
        registrado_por = excluded.registrado_por
  returning id into v_id;
  return v_id;
end $$;

create function public.eliminar_cambio_medidor(p_corte uuid, p_manguera uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
begin
  perform public._corte_editable(p_corte);
  delete from public.cambios_medidor where corte_id = p_corte and manguera_id = p_manguera;
end $$;

-- ───────────── Compras ─────────────
create function public.registrar_compra(
  p_corte uuid, p_tanque uuid, p_galones numeric, p_proveedor text default null)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  c public.cortes;
  t public.tanques;
  v_nivel numeric;
  v_id uuid;
begin
  c := public._corte_editable(p_corte);
  select * into t from public.tanques where id = p_tanque and sucursal_id = c.sucursal_id;
  if not found then raise exception 'El tanque no pertenece a la sucursal.'; end if;
  perform public._validar_galones(p_galones);

  v_nivel := public._nivel_estimado(p_tanque);
  if v_nivel + p_galones > t.capacidad_gal then
    raise exception 'La compra excede el espacio libre del tanque (libre: % gal).', round(t.capacidad_gal - v_nivel, 2);
  end if;

  insert into public.compras_combustible (corte_id, sucursal_id, tanque_id, galones, proveedor, creado_por)
  values (p_corte, c.sucursal_id, p_tanque, p_galones, nullif(btrim(p_proveedor), ''), auth.uid())
  returning id into v_id;
  return v_id;
end $$;

create function public.editar_compra(p_id uuid, p_galones numeric, p_proveedor text default null)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  l public.compras_combustible;
  t public.tanques;
  v_nivel numeric;
begin
  select * into l from public.compras_combustible where id = p_id;
  if not found then raise exception 'No se encontró la compra.'; end if;
  perform public._corte_editable(l.corte_id);
  if l.origen <> 'manual' then
    raise exception 'Esta compra la generó un vaciado de tanque y no se puede editar.';
  end if;
  perform public._validar_galones(p_galones);
  select * into t from public.tanques where id = l.tanque_id;

  v_nivel := public._nivel_estimado(l.tanque_id) - l.galones;
  if v_nivel + p_galones > t.capacidad_gal then
    raise exception 'La compra excede el espacio libre del tanque (libre: % gal).', round(t.capacidad_gal - v_nivel, 2);
  end if;

  update public.compras_combustible
     set galones = p_galones, proveedor = nullif(btrim(p_proveedor), '')
   where id = p_id;
end $$;

create function public.eliminar_compra(p_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare l public.compras_combustible;
begin
  select * into l from public.compras_combustible where id = p_id;
  if not found then raise exception 'No se encontró la compra.'; end if;
  perform public._corte_editable(l.corte_id);
  if l.origen <> 'manual' then
    raise exception 'Esta compra la generó un vaciado de tanque y no se puede eliminar.';
  end if;
  if public._nivel_estimado(l.tanque_id) - l.galones < 0 then
    raise exception 'No se puede eliminar: el nivel estimado del tanque quedaría negativo.';
  end if;
  delete from public.compras_combustible where id = p_id;
end $$;

-- ───────────── Pérdidas ─────────────
create function public.registrar_perdida(
  p_corte uuid, p_tanque uuid, p_tipo public.tipo_perdida, p_galones numeric,
  p_bomba uuid, p_nota text)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  c public.cortes;
  v_id uuid;
begin
  c := public._corte_editable(p_corte);
  if not exists (select 1 from public.tanques where id = p_tanque and sucursal_id = c.sucursal_id) then
    raise exception 'El tanque no pertenece a la sucursal.';
  end if;
  if p_tipo = 'contaminacion' then
    raise exception 'La contaminación se registra con "Descarga errónea y vaciado".';
  end if;
  perform public._validar_galones(p_galones);
  if p_nota is null or length(btrim(p_nota)) < 3 then
    raise exception 'La nota es obligatoria.';
  end if;
  if p_galones > public._nivel_estimado(p_tanque) then
    raise exception 'La pérdida supera el nivel estimado del tanque (% gal).', public._nivel_estimado(p_tanque);
  end if;
  if p_bomba is not null
     and not exists (select 1 from public.bombas where id = p_bomba and sucursal_id = c.sucursal_id) then
    raise exception 'La bomba no pertenece a la sucursal.';
  end if;

  insert into public.perdidas_combustible
    (corte_id, sucursal_id, tanque_id, tipo, galones, bomba_id, nota, creado_por)
  values (p_corte, c.sucursal_id, p_tanque, p_tipo, p_galones, p_bomba, btrim(p_nota), auth.uid())
  returning id into v_id;
  return v_id;
end $$;

create function public.editar_perdida(
  p_id uuid, p_tipo public.tipo_perdida, p_galones numeric, p_bomba uuid, p_nota text)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  l public.perdidas_combustible;
begin
  select * into l from public.perdidas_combustible where id = p_id;
  if not found then raise exception 'No se encontró la pérdida.'; end if;
  perform public._corte_editable(l.corte_id);
  if l.origen <> 'manual' then
    raise exception 'Esta pérdida la generó un vaciado de tanque y no se puede editar.';
  end if;
  if p_tipo = 'contaminacion' then
    raise exception 'La contaminación se registra con "Descarga errónea y vaciado".';
  end if;
  perform public._validar_galones(p_galones);
  if p_nota is null or length(btrim(p_nota)) < 3 then
    raise exception 'La nota es obligatoria.';
  end if;
  if p_galones > public._nivel_estimado(l.tanque_id) + l.galones then
    raise exception 'La pérdida supera el nivel estimado del tanque.';
  end if;
  if p_bomba is not null
     and not exists (select 1 from public.bombas where id = p_bomba and sucursal_id = l.sucursal_id) then
    raise exception 'La bomba no pertenece a la sucursal.';
  end if;

  update public.perdidas_combustible
     set tipo = p_tipo, galones = p_galones, bomba_id = p_bomba, nota = btrim(p_nota)
   where id = p_id;
end $$;

create function public.eliminar_perdida(p_id uuid)
returns void
language plpgsql security definer set search_path = ''
as $$
declare l public.perdidas_combustible;
begin
  select * into l from public.perdidas_combustible where id = p_id;
  if not found then raise exception 'No se encontró la pérdida.'; end if;
  perform public._corte_editable(l.corte_id);
  if l.origen <> 'manual' then
    raise exception 'Esta pérdida la generó un vaciado de tanque y no se puede eliminar.';
  end if;
  delete from public.perdidas_combustible where id = p_id;
end $$;

-- ───────────── Descarga errónea y vaciado de tanque ─────────────
create function public.registrar_vaciado(
  p_corte uuid, p_tanque uuid, p_motivo public.motivo_vaciado, p_nivel_medido numeric,
  p_combustible_erroneo public.combustible, p_galones_erroneos numeric, p_nota text)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  c public.cortes;
  t public.tanques;
  t2 public.tanques;
  v_id uuid;
  v_previo numeric;
begin
  c := public._corte_editable(p_corte);
  select * into t from public.tanques where id = p_tanque and sucursal_id = c.sucursal_id;
  if not found then raise exception 'El tanque no pertenece a la sucursal.'; end if;
  if p_nota is null or length(btrim(p_nota)) < 3 then
    raise exception 'La nota es obligatoria.';
  end if;
  perform public._validar_galones(p_nivel_medido, 'El nivel medido');
  if p_nivel_medido > t.capacidad_gal then
    raise exception 'El nivel medido no puede superar la capacidad del tanque.';
  end if;

  if p_motivo = 'descarga_erronea' then
    if p_combustible_erroneo is null or p_combustible_erroneo = t.combustible then
      raise exception 'El combustible descargado por error debe ser distinto al del tanque.';
    end if;
    perform public._validar_galones(p_galones_erroneos, 'Los galones descargados por error');
    if p_galones_erroneos > p_nivel_medido then
      raise exception 'Los galones descargados por error no pueden superar el nivel medido.';
    end if;
    select * into t2 from public.tanques
     where sucursal_id = c.sucursal_id and combustible = p_combustible_erroneo
     order by numero limit 1;
    if not found then raise exception 'La sucursal no tiene tanque de %.', p_combustible_erroneo; end if;
    v_previo := p_nivel_medido - p_galones_erroneos;
  else
    p_combustible_erroneo := null;
    p_galones_erroneos := null;
    v_previo := p_nivel_medido;
  end if;

  insert into public.vaciados_tanque
    (corte_id, sucursal_id, tanque_id, motivo, combustible_erroneo, galones_erroneos,
     nivel_medido_gal, nota, registrado_por)
  values (p_corte, c.sucursal_id, p_tanque, p_motivo, p_combustible_erroneo, p_galones_erroneos,
          p_nivel_medido, btrim(p_nota), auth.uid())
  returning id into v_id;

  -- Lo que había en el tanque antes de la mezcla se pierde por contaminación
  if v_previo > 0 then
    insert into public.perdidas_combustible
      (corte_id, sucursal_id, tanque_id, tipo, galones, nota, origen, vaciado_id, creado_por)
    values (p_corte, c.sucursal_id, p_tanque, 'contaminacion', v_previo, btrim(p_nota), 'vaciado', v_id, auth.uid());
  end if;

  -- El combustible equivocado: se compró y se perdió (neto cero en su tanque)
  if p_motivo = 'descarga_erronea' then
    insert into public.compras_combustible
      (corte_id, sucursal_id, tanque_id, galones, origen, vaciado_id, creado_por)
    values (p_corte, c.sucursal_id, t2.id, p_galones_erroneos, 'vaciado', v_id, auth.uid());
    insert into public.perdidas_combustible
      (corte_id, sucursal_id, tanque_id, tipo, galones, nota, origen, vaciado_id, creado_por)
    values (p_corte, c.sucursal_id, t2.id, 'contaminacion', p_galones_erroneos,
            'Descargado por error en el tanque de ' || t.combustible || '. ' || btrim(p_nota),
            'vaciado', v_id, auth.uid());
  end if;

  return v_id;
end $$;

-- ───────────── Cierre de corte ─────────────
create function public.cerrar_corte(
  p_corte uuid, p_niveles jsonb, p_tipo_inicial public.tipo_corte default null)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  c public.cortes;
  s public.sucursales;
  prev public.cortes;
  t public.tanques;
  r record;
  v_item jsonb;
  v_faltan text;
  v_tipo public.tipo_corte;
  v_fecha date;
  v_hoy date := (now() at time zone 'America/El_Salvador')::date;
  v_nivel numeric;
  v_vistos uuid[] := '{}';
  v_precio numeric;
  v_comb public.combustible;
  v_sig uuid;
begin
  select * into c from public.cortes where id = p_corte for update;
  if not found then raise exception 'No se encontró el corte.'; end if;
  perform public._exigir_gerente_sucursal(c.sucursal_id);
  if c.estado <> 'en_curso' then raise exception 'El corte ya está cerrado.'; end if;
  select * into s from public.sucursales where id = c.sucursal_id;

  -- 1) Las 6 bombas con sus 3 lecturas
  select string_agg(x.num::text, ', ' order by x.num) into v_faltan
  from (
    select distinct b.numero as num
    from public.mangueras m
    join public.bombas b on b.id = m.bomba_id
    where m.sucursal_id = c.sucursal_id
      and not exists (select 1 from public.lecturas_manguera l
                       where l.corte_id = c.id and l.manguera_id = m.id)
  ) x;
  if v_faltan is not null then
    raise exception 'Faltan lecturas de las bombas: %.', v_faltan;
  end if;

  -- 2) Consistencia de las lecturas
  for r in select * from public.v_lecturas_efectivas where corte_id = c.id loop
    if r.lectura_inicial_gal is null then
      raise exception 'Falta la lectura inicial de la Bomba % (%).', r.bomba_numero, r.combustible;
    end if;
    if r.galones < 0 then
      raise exception 'La lectura final de la Bomba % (%) es menor que la inicial.', r.bomba_numero, r.combustible;
    end if;
  end loop;

  -- 3) Niveles medidos de todos los tanques
  if jsonb_typeof(p_niveles) <> 'array'
     or jsonb_array_length(p_niveles) <> (select count(*) from public.tanques where sucursal_id = c.sucursal_id) then
    raise exception 'Falta el nivel medido de algún tanque.';
  end if;
  for v_item in select * from jsonb_array_elements(p_niveles) loop
    select * into t from public.tanques
     where id = (v_item ->> 'tanque_id')::uuid and sucursal_id = c.sucursal_id;
    if not found then raise exception 'Hay un tanque que no pertenece a la sucursal.'; end if;
    if t.id = any (v_vistos) then raise exception 'Cada tanque debe aparecer una sola vez.'; end if;
    v_vistos := v_vistos || t.id;

    v_nivel := (v_item ->> 'nivel_medido_gal')::numeric;
    if v_nivel is null or v_nivel < 0 or v_nivel <> round(v_nivel, 2) then
      raise exception 'El nivel del tanque de % debe ser un número mayor o igual a 0 con máximo 2 decimales.', t.combustible;
    end if;
    if v_nivel > t.capacidad_gal then
      raise exception 'El nivel del tanque de % no puede superar su capacidad (% gal).', t.combustible, t.capacidad_gal;
    end if;
    insert into public.niveles_tanque_corte (corte_id, sucursal_id, tanque_id, nivel_medido_gal)
    values (c.id, c.sucursal_id, t.id, v_nivel);
  end loop;

  -- 4) Precios vigentes (se congelan en el corte)
  foreach v_comb in array enum_range(null::public.combustible) loop
    select p.precio_gal into v_precio from public.precios p
     where p.sucursal_id = c.sucursal_id and p.combustible = v_comb and p.vigente_desde <= now()
     order by p.vigente_desde desc limit 1;
    if v_precio is null then
      raise exception 'La sucursal no tiene precio de % configurado: pídele al Gerente General que lo fije.', v_comb;
    end if;
    insert into public.precios_corte (corte_id, sucursal_id, combustible, precio_gal)
    values (c.id, c.sucursal_id, v_comb, v_precio);
  end loop;

  -- 5) Cajas cerradas
  if s.tiene_tienda and exists (
    select 1 from public.sesiones_caja where corte_id = c.id and cerrada_en is null
  ) then
    raise exception 'Hay cajas abiertas: cierra las cajas antes de cerrar el corte.';
  end if;

  -- 6) Tipo (alternan) y fecha operativa (el Vespertino hereda la del Matutino)
  select * into prev from public.cortes where sucursal_id = c.sucursal_id and secuencia = c.secuencia - 1;
  if not found then
    if p_tipo_inicial is null then
      raise exception 'Indica si este primer corte es Matutino o Vespertino.';
    end if;
    v_tipo := p_tipo_inicial;
    v_fecha := v_hoy;
  else
    v_tipo := (case prev.tipo when 'matutino' then 'vespertino' else 'matutino' end)::public.tipo_corte;
    v_fecha := case when v_tipo = 'vespertino' then prev.fecha_operativa else v_hoy end;
  end if;

  -- 7) Cerrar
  begin
    update public.cortes
       set estado = 'cerrado', cerrado_en = now(), cerrado_por = auth.uid(),
           tipo = v_tipo, fecha_operativa = v_fecha
     where id = c.id;
  exception when unique_violation then
    raise exception 'Ya hay 2 cortes cerrados en esta fecha operativa.';
  end;

  -- 8) Abrir el siguiente corte
  insert into public.cortes (sucursal_id, secuencia) values (c.sucursal_id, c.secuencia + 1)
  returning id into v_sig;

  return jsonb_build_object('corte_id', c.id, 'tipo', v_tipo, 'fecha_operativa', v_fecha,
                            'siguiente_corte_id', v_sig);
end $$;

-- ───────────── Ajustes (Gerente General) ─────────────
create function public.registrar_ajuste(
  p_corte uuid, p_manguera uuid, p_valor numeric, p_motivo text)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  c public.cortes;
  nxt public.cortes;
  v_ini numeric;
  v_cm public.cambios_medidor;
  v_borrador numeric;
  v_id uuid;
begin
  perform public._exigir_gerente_general();
  select * into c from public.cortes where id = p_corte for share;
  if not found then raise exception 'No se encontró el corte.'; end if;
  if c.estado <> 'cerrado' then raise exception 'Solo se ajustan cortes cerrados.'; end if;

  select * into nxt from public.cortes where sucursal_id = c.sucursal_id and secuencia = c.secuencia + 1 for share;
  if found and nxt.estado = 'cerrado' then
    raise exception 'Ya se cerró el corte siguiente: este corte es definitivo y no admite ajustes.';
  end if;

  if not exists (select 1 from public.lecturas_manguera where corte_id = p_corte and manguera_id = p_manguera) then
    raise exception 'Ese corte no tiene lectura de esa manguera.';
  end if;
  if p_valor is null or p_valor < 0 or p_valor <> round(p_valor, 2) then
    raise exception 'El valor debe ser un número mayor o igual a 0 con máximo 2 decimales.';
  end if;
  if p_motivo is null or length(btrim(p_motivo)) < 3 then
    raise exception 'El motivo es obligatorio.';
  end if;

  v_ini := public._lectura_inicial(p_corte, p_manguera);
  select * into v_cm from public.cambios_medidor where corte_id = p_corte and manguera_id = p_manguera;
  if found then
    if p_valor < v_cm.lectura_inicial_nuevo_gal then
      raise exception 'El valor ajustado no puede ser menor que la lectura inicial del medidor nuevo (%).', v_cm.lectura_inicial_nuevo_gal;
    end if;
  elsif p_valor < v_ini then
    raise exception 'El valor ajustado no puede ser menor que la lectura inicial (%).', v_ini;
  end if;

  -- La lectura guardada en el corte en curso no puede quedar por debajo de la nueva inicial
  if nxt.id is not null then
    select lectura_final_gal into v_borrador from public.lecturas_manguera
     where corte_id = nxt.id and manguera_id = p_manguera;
    if v_borrador is not null
       and not exists (select 1 from public.cambios_medidor where corte_id = nxt.id and manguera_id = p_manguera)
       and v_borrador < p_valor then
      raise exception 'La lectura guardada en el corte en curso (%) quedaría por debajo de la nueva lectura inicial.', v_borrador;
    end if;
  end if;

  insert into public.ajustes_lectura (corte_id, sucursal_id, manguera_id, valor_correcto_gal, motivo, ajustado_por)
  values (p_corte, c.sucursal_id, p_manguera, p_valor, btrim(p_motivo), auth.uid())
  returning id into v_id;
  return v_id;
end $$;
