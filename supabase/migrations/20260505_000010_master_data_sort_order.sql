alter table public.income_sources
  add column if not exists sort_order integer not null default 0;

alter table public.debt_types
  add column if not exists sort_order integer not null default 0;

with ranked_income_sources as (
  select
    id,
    row_number() over (
      partition by couple_id
      order by created_at, name, id
    ) - 1 as rn
  from public.income_sources
  where is_deleted = false
)
update public.income_sources i
set sort_order = r.rn
from ranked_income_sources r
where i.id = r.id;

with ranked_debt_types as (
  select
    id,
    row_number() over (
      partition by couple_id
      order by created_at, name, id
    ) - 1 as rn
  from public.debt_types
  where is_deleted = false
)
update public.debt_types d
set sort_order = r.rn
from ranked_debt_types r
where d.id = r.id;

create index if not exists idx_income_sources_sort_order
  on public.income_sources(couple_id, sort_order)
  where is_deleted = false;

create index if not exists idx_debt_types_sort_order
  on public.debt_types(couple_id, sort_order)
  where is_deleted = false;