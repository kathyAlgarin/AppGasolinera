-- 12 · Versión final de v_nivel_tanque_estimado (3/3)
-- Las marcas de tiempo de compras, pérdidas y vaciados usan el reloj real de cada fila (clock_timestamp),
-- y las líneas generadas por el vaciado base se excluyen explícitamente por su vaciado_id.

alter table public.compras_combustible  alter column creado_en set default clock_timestamp();
alter table public.perdidas_combustible alter column creado_en set default clock_timestamp();
alter table public.vaciados_tanque      alter column creado_en set default clock_timestamp();

create or replace view public.v_nivel_tanque_estimado with (security_invoker = true) as
select t.id as tanque_id, t.sucursal_id, t.combustible, t.capacidad_gal,
       base.nivel_gal as nivel_base_gal, base.base_en,
       cp.galones as compras_gal, cp.n as n_compras,
       pd.galones as perdidas_gal, pd.n as n_perdidas,
       greatest(base.nivel_gal + cp.galones - pd.galones, 0)::numeric(12,2) as nivel_estimado_gal,
       round(100 * greatest(base.nivel_gal + cp.galones - pd.galones, 0) / t.capacidad_gal, 1) as porcentaje
from public.tanques t
cross join lateral (
  select q.nivel_gal, q.base_en, q.desde, q.vaciado_id
  from (
    (select 0::numeric(12,2) as nivel_gal, v.creado_en as base_en, v.creado_en as desde,
            v.id as vaciado_id, 1 as prio
       from public.vaciados_tanque v
       join public.cortes c on c.id = v.corte_id and c.estado = 'en_curso'
      where v.tanque_id = t.id
      order by v.creado_en desc limit 1)
    union all
    (select n.nivel_medido_gal, c.cerrado_en, '-infinity'::timestamptz, null::uuid, 2
       from public.niveles_tanque_corte n
       join public.cortes c on c.id = n.corte_id and c.estado = 'cerrado'
      where n.tanque_id = t.id
      order by c.secuencia desc limit 1)
    union all
    (select t.nivel_inicial_gal, t.creado_en, '-infinity'::timestamptz, null::uuid, 3)
  ) q
  order by q.prio
  limit 1
) base
cross join lateral (
  select coalesce(sum(x.galones), 0)::numeric(12,2) as galones, count(x.id) as n
  from public.compras_combustible x
  join public.cortes c on c.id = x.corte_id and c.estado = 'en_curso'
  where x.tanque_id = t.id
    and x.creado_en > base.desde
    and (base.vaciado_id is null or x.vaciado_id is distinct from base.vaciado_id)
) cp
cross join lateral (
  select coalesce(sum(x.galones), 0)::numeric(12,2) as galones, count(x.id) as n
  from public.perdidas_combustible x
  join public.cortes c on c.id = x.corte_id and c.estado = 'en_curso'
  where x.tanque_id = t.id
    and x.creado_en > base.desde
    and (base.vaciado_id is null or x.vaciado_id is distinct from base.vaciado_id)
) pd;
