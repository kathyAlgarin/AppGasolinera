-- 09 · Seguridad por fila (RLS) y permisos
-- Ver docs/BASE_DE_DATOS.md (sección 7). Principio: todo cerrado por defecto; solo se abre lo necesario.
-- Las escrituras de negocio entran únicamente por funciones (security definer); las tablas solo se leen.

-- 1) Cerrar todo y evitar que lo nuevo quede expuesto automáticamente
revoke all on all tables    in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;

alter default privileges in schema public revoke all on tables    from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;
alter default privileges in schema public revoke all on functions from public, anon, authenticated;

-- 2) RLS activo en todas las tablas
do $$
declare t record;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', t.tablename);
  end loop;
end $$;

-- 3) Lectura "de personal": Gerente General ve todo; Gerente de Sucursal solo su sucursal
do $$
declare t text;
begin
  foreach t in array array[
    'tanques','bombas','mangueras','cortes','lecturas_manguera','cambios_medidor','niveles_tanque_corte',
    'vaciados_tanque','compras_combustible','perdidas_combustible','ajustes_lectura','precios','precios_corte',
    'entradas_inventario','bajas_inventario','empleados','turnos','asignaciones_turno',
    'inventario_sucursal','sesiones_caja','ventas','venta_lineas'
  ] loop
    execute format(
      $f$create policy "personal_lee" on public.%I for select to authenticated
         using (public.es_gerente_general()
                or (public.mi_rol() = 'gerente_sucursal' and sucursal_id = public.mi_sucursal()))$f$, t);
    execute format('grant select on public.%I to authenticated', t);
  end loop;
end $$;

-- 4) Casos particulares de lectura
create policy "sucursales_lee" on public.sucursales for select to authenticated
  using (public.es_gerente_general() or id = public.mi_sucursal());
grant select on public.sucursales to authenticated;

create policy "perfiles_lee" on public.perfiles for select to authenticated
  using (public.es_gerente_general()
         or id = auth.uid()
         or (public.mi_rol() = 'gerente_sucursal' and sucursal_id = public.mi_sucursal()));
grant select on public.perfiles to authenticated;

create policy "configuracion_lee" on public.configuracion for select to authenticated
  using (public.mi_rol() in ('gerente_general', 'gerente_sucursal'));
grant select on public.configuracion to authenticated;

-- Catálogo: todos los roles leen los activos; el Gerente General lee y escribe todo
create policy "articulos_lee" on public.articulos for select to authenticated
  using (public.es_gerente_general() or activo);
create policy "articulos_crea" on public.articulos for insert to authenticated
  with check (public.es_gerente_general());
create policy "articulos_edita" on public.articulos for update to authenticated
  using (public.es_gerente_general()) with check (public.es_gerente_general());
grant select, insert, update on public.articulos to authenticated;

-- Cajero: ve el inventario de su sucursal, y solo sus propias cajas, ventas y líneas
create policy "cajero_lee_inventario" on public.inventario_sucursal for select to authenticated
  using (public.mi_rol() = 'cajero' and sucursal_id = public.mi_sucursal());
create policy "cajero_lee_sus_cajas" on public.sesiones_caja for select to authenticated
  using (public.mi_rol() = 'cajero' and cajero_id = auth.uid());
create policy "cajero_lee_sus_ventas" on public.ventas for select to authenticated
  using (public.mi_rol() = 'cajero' and cajero_id = auth.uid());
create policy "cajero_lee_sus_lineas" on public.venta_lineas for select to authenticated
  using (public.mi_rol() = 'cajero'
         and exists (select 1 from public.ventas v where v.id = venta_id and v.cajero_id = auth.uid()));

-- 5) Escritura directa: solo personal, turnos y asignaciones, por el Gerente de su sucursal
create policy "gs_crea_empleados" on public.empleados for insert to authenticated
  with check (public.mi_rol() = 'gerente_sucursal' and sucursal_id = public.mi_sucursal());
create policy "gs_edita_empleados" on public.empleados for update to authenticated
  using (public.mi_rol() = 'gerente_sucursal' and sucursal_id = public.mi_sucursal())
  with check (public.mi_rol() = 'gerente_sucursal' and sucursal_id = public.mi_sucursal());
grant insert, update on public.empleados to authenticated;

create policy "gs_crea_turnos" on public.turnos for insert to authenticated
  with check (public.mi_rol() = 'gerente_sucursal' and sucursal_id = public.mi_sucursal());
create policy "gs_edita_turnos" on public.turnos for update to authenticated
  using (public.mi_rol() = 'gerente_sucursal' and sucursal_id = public.mi_sucursal())
  with check (public.mi_rol() = 'gerente_sucursal' and sucursal_id = public.mi_sucursal());
grant insert, update on public.turnos to authenticated;

create policy "gs_crea_asignaciones" on public.asignaciones_turno for insert to authenticated
  with check (public.mi_rol() = 'gerente_sucursal' and sucursal_id = public.mi_sucursal());
create policy "gs_edita_asignaciones" on public.asignaciones_turno for update to authenticated
  using (public.mi_rol() = 'gerente_sucursal' and sucursal_id = public.mi_sucursal())
  with check (public.mi_rol() = 'gerente_sucursal' and sucursal_id = public.mi_sucursal());
create policy "gs_quita_asignaciones" on public.asignaciones_turno for delete to authenticated
  using (public.mi_rol() = 'gerente_sucursal' and sucursal_id = public.mi_sucursal());
grant insert, update, delete on public.asignaciones_turno to authenticated;

-- 6) Vistas: solo lectura para usuarios autenticados (las filtra el RLS de las tablas de origen)
do $$
declare v record;
begin
  for v in select viewname from pg_views where schemaname = 'public' loop
    execute format('grant select on public.%I to authenticated', v.viewname);
  end loop;
end $$;

-- 7) Funciones que pueden llamar los usuarios autenticados (las demás son internas)
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as firma
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = any (array[
        'mi_rol','mi_sucursal','es_gerente_general','cfg','marcar_password_cambiada',
        'crear_sucursal','editar_sucursal','cambiar_estado_sucursal','configurar_tienda','fijar_precio',
        'guardar_lecturas_bomba','registrar_cambio_medidor','eliminar_cambio_medidor',
        'registrar_compra','editar_compra','eliminar_compra',
        'registrar_perdida','editar_perdida','eliminar_perdida',
        'registrar_vaciado','cerrar_corte','registrar_ajuste',
        'registrar_entrada','eliminar_entrada','registrar_baja','eliminar_baja',
        'abrir_caja','registrar_venta','anular_venta','cerrar_caja','cerrar_caja_forzado',
        'empleados_en_turno'])
  loop
    execute format('grant execute on function %s to authenticated', f.firma);
  end loop;
end $$;
