-- 13 · Vista previa del cierre de un corte (solo lectura)
-- El cuadre de las vistas solo existe para cortes cerrados. Para mostrar el resumen ANTES de cerrar
-- ("Resumen y cierre"), la app llama a esta función con los niveles medidos que el gerente tecleó.
-- No escribe nada: usa las mismas fórmulas de v_cuadre_tanque_corte, así la app no calcula cuadres por su cuenta.

create function public.resumen_previo_corte(p_corte uuid, p_niveles jsonb default '[]'::jsonb)
returns table (
  combustible         public.combustible,
  tanque_id           uuid,
  galones_vendidos    numeric,
  precio_gal          numeric,
  ingreso_usd         numeric,
  compras_gal         numeric,
  perdidas_gal        numeric,
  nivel_inicial_gal   numeric,
  nivel_teorico_gal   numeric,
  nivel_medido_gal    numeric,
  diferencia_gal      numeric,
  hay_diferencia      boolean,
  hay_cambio_medidor  boolean)
language plpgsql stable security definer set search_path = ''
as $$
declare c public.cortes;
begin
  select * into c from public.cortes where id = p_corte;
  if not found then raise exception 'No se encontró el corte.'; end if;
  if not (public.es_gerente_general()
          or (public.mi_rol() = 'gerente_sucursal' and public.mi_sucursal() = c.sucursal_id)) then
    raise exception 'Solo el Gerente de esta sucursal puede hacer esto.' using errcode = '42501';
  end if;
  if p_niveles is not null and jsonb_typeof(p_niveles) <> 'array' then
    raise exception 'Los niveles medidos deben ser una lista.';
  end if;

  return query
  with med as (
    select le.combustible, sum(le.galones) as g, bool_or(le.cambio_medidor) as cm
    from public.v_lecturas_efectivas le
    where le.corte_id = p_corte
    group by le.combustible
  ), niv as (
    select (x ->> 'tanque_id')::uuid as tanque_id, (x ->> 'nivel_medido_gal')::numeric as nivel
    from jsonb_array_elements(coalesce(p_niveles, '[]'::jsonb)) x
  ), pr as (
    select distinct on (p.combustible) p.combustible, p.precio_gal
    from public.precios p
    where p.sucursal_id = c.sucursal_id and p.vigente_desde <= now()
    order by p.combustible, p.vigente_desde desc
  ), comp as (
    select cc.tanque_id, sum(cc.galones) as g from public.compras_combustible cc
    where cc.corte_id = p_corte group by cc.tanque_id
  ), perd as (
    select pc.tanque_id, sum(pc.galones) as g from public.perdidas_combustible pc
    where pc.corte_id = p_corte group by pc.tanque_id
  ), x as (
    select t.combustible as comb, t.id as tid,
           coalesce(med.g, 0) as galones, pr.precio_gal as precio,
           coalesce(comp.g, 0) as compras, coalesce(perd.g, 0) as perdidas,
           case when c.secuencia = 1 then t.nivel_inicial_gal
                else (select pn.nivel_medido_gal
                        from public.niveles_tanque_corte pn
                        join public.cortes pcor on pcor.id = pn.corte_id
                       where pcor.sucursal_id = c.sucursal_id
                         and pcor.secuencia = c.secuencia - 1
                         and pn.tanque_id = t.id)
           end as inicial,
           niv.nivel as medido,
           coalesce(med.cm, false) as cambio
    from public.tanques t
    left join med  on med.combustible = t.combustible
    left join pr   on pr.combustible = t.combustible
    left join comp on comp.tanque_id = t.id
    left join perd on perd.tanque_id = t.id
    left join niv  on niv.tanque_id = t.id
    where t.sucursal_id = c.sucursal_id
  )
  select x.comb, x.tid, x.galones, x.precio,
         case when x.precio is null then null else round(x.galones * x.precio, 2) end,
         x.compras, x.perdidas, x.inicial,
         (x.inicial + x.compras - x.galones - x.perdidas),
         x.medido,
         case when x.medido is null then null
              else x.medido - (x.inicial + x.compras - x.galones - x.perdidas) end,
         case when x.medido is null then null
              else abs(x.medido - (x.inicial + x.compras - x.galones - x.perdidas))
                   > greatest(public.cfg('tolerancia_cuadre_pct') / 100 * x.galones, 0.01) end,
         x.cambio
  from x
  order by x.comb;
end $$;

revoke all on function public.resumen_previo_corte(uuid, jsonb) from public, anon;
grant execute on function public.resumen_previo_corte(uuid, jsonb) to authenticated;
