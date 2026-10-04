-- 14 · Stock mínimo por sucursal
-- El inventario solo lo modifican funciones, pero ninguna permitía fijar el stock mínimo (siempre quedaba en 0),
-- así que el indicador «Stock bajo» nunca avisaba antes de agotarse. Lo fija el Gerente de Sucursal de su sucursal.

create function public.fijar_stock_minimo(p_articulo uuid, p_minimo integer)
returns void
language plpgsql security definer set search_path = ''
as $$
declare v_suc uuid := public.mi_sucursal();
begin
  if public.mi_rol() is distinct from 'gerente_sucursal' or v_suc is null then
    raise exception 'Solo el Gerente de Sucursal puede hacer esto.' using errcode = '42501';
  end if;
  if p_minimo is null or p_minimo < 0 then
    raise exception 'El stock mínimo debe ser un número entero mayor o igual a 0.';
  end if;
  update public.inventario_sucursal
     set stock_minimo = p_minimo
   where sucursal_id = v_suc and articulo_id = p_articulo;
  if not found then
    raise exception 'Ese artículo no está en el inventario de la sucursal.';
  end if;
end $$;

revoke all on function public.fijar_stock_minimo(uuid, integer) from public, anon;
grant execute on function public.fijar_stock_minimo(uuid, integer) to authenticated;
