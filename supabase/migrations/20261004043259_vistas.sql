-- 06 · Vistas (security_invoker: respetan RLS del usuario que consulta)
-- Ver docs/BASE_DE_DATOS.md (sección 6)
-- Límite conocido: el cuadre asume 1 tanque por combustible en cada sucursal.

-- Lecturas efectivas por corte y manguera (con ajustes y cambio de medidor)
create view public.v_lecturas_efectivas with (security_invoker = true) as
with base as (
  select lm.corte_id, lm.sucursal_id, lm.manguera_id, c.secuencia,
         lm.lectura_inicial_manual_gal,
         lm.lectura_final_gal as final_original,
         coalesce(aj.valor_correcto_gal, lm.lectura_final_gal) as final_efectiva,
         aj.valor_correcto_gal is not null as ajustada
  from public.lecturas_manguera lm
  join public.cortes c on c.id = lm.corte_id
  left join lateral (
    select a.valor_correcto_gal
    from public.ajustes_lectura a
    where a.corte_id = lm.corte_id and a.manguera_id = lm.manguera_id
    order by a.creado_en desc
    limit 1
  ) aj on true
), con_inicial as (
  select b.*,
         case when b.secuencia = 1 then b.lectura_inicial_manual_gal else p.final_efectiva end
           as lectura_inicial_gal
  from base b
  left join public.cortes pc
         on pc.sucursal_id = b.sucursal_id and pc.secuencia = b.secuencia - 1
  left join base p
         on p.corte_id = pc.id and p.manguera_id = b.manguera_id
)
select ci.corte_id, ci.sucursal_id, ci.manguera_id, m.bomba_id, bo.numero as bomba_numero,
       m.combustible,
       ci.lectura_inicial_gal,
       ci.final_original,
       ci.final_efectiva as lectura_final_gal,
       ci.ajustada,
       (cm.id is not null) as cambio_medidor,
       case when cm.id is not null
            then (cm.lectura_final_viejo_gal - ci.lectura_inicial_gal)
               + (ci.final_efectiva - cm.lectura_inicial_nuevo_gal)
            else ci.final_efectiva - ci.lectura_inicial_gal
       end as galones
from con_inicial ci
join public.mangueras m  on m.id = ci.manguera_id
join public.bombas bo    on bo.id = m.bomba_id
left join public.cambios_medidor cm
       on cm.corte_id = ci.corte_id and cm.manguera_id = ci.manguera_id;

-- Galones e ingreso por corte y combustible
create view public.v_ventas_combustible_corte with (security_invoker = true) as
select le.corte_id, le.sucursal_id, le.combustible,
       sum(le.galones)::numeric(14,2) as galones_vendidos,
       round(sum(le.galones) * pc.precio_gal, 2) as ingreso_usd,
       c.estado, c.tipo, c.fecha_operativa, c.cerrado_en
from public.v_lecturas_efectivas le
join public.cortes c on c.id = le.corte_id
left join public.precios_corte pc
       on pc.corte_id = le.corte_id and pc.combustible = le.combustible
group by le.corte_id, le.sucursal_id, le.combustible, pc.precio_gal,
         c.estado, c.tipo, c.fecha_operativa, c.cerrado_en;

-- Nivel estimado de cada tanque:
--   base = vaciado del corte en curso (0) | último nivel medido de un corte cerrado | nivel inicial
--   + compras − pérdidas registradas en el corte en curso posteriores a la base
create view public.v_nivel_tanque_estimado with (security_invoker = true) as
select t.id as tanque_id, t.sucursal_id, t.combustible, t.capacidad_gal,
       base.nivel_gal as nivel_base_gal, base.base_en,
       cp.galones as compras_gal, cp.n as n_compras,
       pd.galones as perdidas_gal, pd.n as n_perdidas,
       greatest(base.nivel_gal + cp.galones - pd.galones, 0)::numeric(12,2) as nivel_estimado_gal,
       round(100 * greatest(base.nivel_gal + cp.galones - pd.galones, 0) / t.capacidad_gal, 1) as porcentaje
from public.tanques t
cross join lateral (
  select q.nivel_gal, q.base_en
  from (
    (select 0::numeric(12,2) as nivel_gal, v.creado_en as base_en, 1 as prio
       from public.vaciados_tanque v
       join public.cortes c on c.id = v.corte_id and c.estado = 'en_curso'
      where v.tanque_id = t.id
      order by v.creado_en desc limit 1)
    union all
    (select n.nivel_medido_gal, c.cerrado_en, 2
       from public.niveles_tanque_corte n
       join public.cortes c on c.id = n.corte_id and c.estado = 'cerrado'
      where n.tanque_id = t.id
      order by c.cerrado_en desc limit 1)
    union all
    (select t.nivel_inicial_gal, t.creado_en, 3)
  ) q
  order by q.prio
  limit 1
) base
cross join lateral (
  select coalesce(sum(x.galones), 0)::numeric(12,2) as galones, count(x.id) as n
  from public.compras_combustible x
  join public.cortes c on c.id = x.corte_id and c.estado = 'en_curso'
  where x.tanque_id = t.id and x.creado_en > base.base_en
) cp
cross join lateral (
  select coalesce(sum(x.galones), 0)::numeric(12,2) as galones, count(x.id) as n
  from public.perdidas_combustible x
  join public.cortes c on c.id = x.corte_id and c.estado = 'en_curso'
  where x.tanque_id = t.id and x.creado_en > base.base_en
) pd;

-- Estado del tanque: el peor entre porcentaje y autonomía
create view public.v_estado_tanque with (security_invoker = true) as
with p as (
  select public.cfg('tanque_critico_pct')     as crit_pct,
         public.cfg('tanque_medio_pct')       as med_pct,
         public.cfg('autonomia_critica_dias') as crit_dias,
         public.cfg('autonomia_media_dias')   as med_dias,
         public.cfg('autonomia_ventana_dias')::int as ventana,
         (now() at time zone 'America/El_Salvador')::date as hoy
), hist as (
  select vc.sucursal_id, vc.combustible,
         min(vc.fecha_operativa) as primera_fecha,
         sum(vc.galones_vendidos)
           filter (where vc.fecha_operativa >= p.hoy - p.ventana and vc.fecha_operativa < p.hoy)
           as galones_ventana
  from public.v_ventas_combustible_corte vc
  cross join p
  where vc.estado = 'cerrado'
  group by vc.sucursal_id, vc.combustible
), calc as (
  select n.*, p.ventana,
         case when h.primera_fecha is not null
                and h.primera_fecha <= p.hoy - p.ventana
                and coalesce(h.galones_ventana, 0) > 0
              then round(n.nivel_estimado_gal / (h.galones_ventana / p.ventana), 1)
         end as autonomia_dias,
         case when n.porcentaje <= p.crit_pct then 1
              when n.porcentaje <= p.med_pct  then 2 else 3 end as rango_pct,
         p.crit_dias, p.med_dias
  from public.v_nivel_tanque_estimado n
  cross join p
  left join hist h on h.sucursal_id = n.sucursal_id and h.combustible = n.combustible
)
select tanque_id, sucursal_id, combustible, capacidad_gal, nivel_estimado_gal, porcentaje,
       n_compras, n_perdidas, base_en,
       autonomia_dias,
       (autonomia_dias is not null) as autonomia_disponible,
       case least(rango_pct,
                  case when autonomia_dias is null then 3
                       when autonomia_dias < crit_dias then 1
                       when autonomia_dias < med_dias  then 2 else 3 end)
            when 1 then 'critico' when 2 then 'medio' else 'optimo' end as estado
from calc;

-- Cuadre medidor vs tanque por corte cerrado
create view public.v_cuadre_tanque_corte with (security_invoker = true) as
with comp as (
  select corte_id, tanque_id, sum(galones) as g from public.compras_combustible group by 1, 2
), perd as (
  select corte_id, tanque_id, sum(galones) as g from public.perdidas_combustible group by 1, 2
), med as (
  select corte_id, combustible, sum(galones) as g from public.v_lecturas_efectivas group by 1, 2
), x as (
  select n.corte_id, c.sucursal_id, n.tanque_id, t.combustible,
         case when c.secuencia = 1 then t.nivel_inicial_gal
              else (select pn.nivel_medido_gal
                      from public.niveles_tanque_corte pn
                      join public.cortes pc on pc.id = pn.corte_id
                     where pc.sucursal_id = c.sucursal_id
                       and pc.secuencia = c.secuencia - 1
                       and pn.tanque_id = n.tanque_id)
         end as nivel_inicial_gal,
         coalesce(comp.g, 0) as compras_gal,
         coalesce(med.g, 0)  as galones_medidor,
         coalesce(perd.g, 0) as perdidas_gal,
         n.nivel_medido_gal
  from public.niveles_tanque_corte n
  join public.cortes c  on c.id = n.corte_id
  join public.tanques t on t.id = n.tanque_id
  left join comp on comp.corte_id = n.corte_id and comp.tanque_id = n.tanque_id
  left join perd on perd.corte_id = n.corte_id and perd.tanque_id = n.tanque_id
  left join med  on med.corte_id  = n.corte_id and med.combustible = t.combustible
)
select x.*,
       (x.nivel_inicial_gal + x.compras_gal - x.galones_medidor - x.perdidas_gal)
         as nivel_teorico_gal,
       (x.nivel_medido_gal
         - (x.nivel_inicial_gal + x.compras_gal - x.galones_medidor - x.perdidas_gal))
         as diferencia_gal,
       abs(x.nivel_medido_gal
         - (x.nivel_inicial_gal + x.compras_gal - x.galones_medidor - x.perdidas_gal))
         > greatest(public.cfg('tolerancia_cuadre_pct') / 100 * x.galones_medidor, 0.01)
         as hay_diferencia
from x;

-- Reporte consolidado por corte y combustible
create view public.v_resumen_corte with (security_invoker = true) as
select cu.corte_id, cu.sucursal_id, cu.combustible, cu.tanque_id,
       vc.galones_vendidos, vc.ingreso_usd,
       cu.compras_gal, cu.perdidas_gal,
       cu.nivel_inicial_gal, cu.nivel_teorico_gal, cu.nivel_medido_gal,
       cu.diferencia_gal, cu.hay_diferencia,
       exists (select 1 from public.v_lecturas_efectivas l
                where l.corte_id = cu.corte_id and l.combustible = cu.combustible and l.ajustada)
         as hay_ajuste,
       exists (select 1 from public.v_lecturas_efectivas l
                where l.corte_id = cu.corte_id and l.combustible = cu.combustible and l.cambio_medidor)
         as hay_cambio_medidor
from public.v_cuadre_tanque_corte cu
left join public.v_ventas_combustible_corte vc
       on vc.corte_id = cu.corte_id and vc.combustible = cu.combustible;

-- Métricas del dashboard del Gerente General (solo cortes cerrados)
create view public.v_dashboard_combustible with (security_invoker = true) as
select c.sucursal_id, c.fecha_operativa, r.combustible,
       sum(r.galones_vendidos)::numeric(14,2) as galones_vendidos,
       sum(r.ingreso_usd)                     as ingreso_usd,
       sum(r.compras_gal)                     as compras_gal,
       sum(r.perdidas_gal)                    as perdidas_gal,
       count(distinct c.id)                   as cortes_cerrados,
       count(distinct c.id) filter (where r.hay_diferencia) as cortes_con_diferencia
from public.v_resumen_corte r
join public.cortes c on c.id = r.corte_id and c.estado = 'cerrado'
group by c.sucursal_id, c.fecha_operativa, r.combustible;

-- Tienda y servicios
create view public.v_tienda_ingresos with (security_invoker = true) as
select c.sucursal_id, c.fecha_operativa, a.categoria,
       sum(l.cantidad)::bigint as unidades,
       sum(l.subtotal_usd)     as ingreso_usd
from public.ventas v
join public.cortes c on c.id = v.corte_id and c.estado = 'cerrado'
join public.venta_lineas l on l.venta_id = v.id
join public.articulos a on a.id = l.articulo_id
where v.estado = 'completada'
group by c.sucursal_id, c.fecha_operativa, a.categoria;

create view public.v_tienda_anulaciones with (security_invoker = true) as
select c.sucursal_id, c.fecha_operativa, count(*) as ventas_anuladas, sum(v.total_usd) as total_usd
from public.ventas v
join public.cortes c on c.id = v.corte_id and c.estado = 'cerrado'
where v.estado = 'anulada'
group by c.sucursal_id, c.fecha_operativa;

create view public.v_tienda_cajas with (security_invoker = true) as
select s.id as sesion_id, s.sucursal_id, s.cajero_id, p.nombre as cajero_nombre,
       c.fecha_operativa, s.abierta_en, s.cerrada_en,
       s.fondo_inicial_usd, s.efectivo_esperado_usd, s.efectivo_contado_usd, s.diferencia_usd,
       s.cierre_forzado
from public.sesiones_caja s
join public.perfiles p on p.id = s.cajero_id
join public.cortes c   on c.id = s.corte_id;

create view public.v_stock_bajo with (security_invoker = true) as
select i.sucursal_id, i.articulo_id, a.nombre, a.categoria, i.stock, i.stock_minimo
from public.inventario_sucursal i
join public.articulos a on a.id = i.articulo_id
where a.activo and i.stock <= i.stock_minimo;
