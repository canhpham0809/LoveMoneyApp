alter table public.funds
  add column if not exists sort_order integer not null default 0;

alter table public.debts
  add column if not exists sort_order integer not null default 0;

with ranked_funds as (
  select
    id,
    row_number() over (
      partition by couple_id
      order by lower(name), created_at
    ) - 1 as rn
  from public.funds
  where is_deleted = false
)
update public.funds f
set sort_order = rf.rn
from ranked_funds rf
where f.id = rf.id;

with ranked_debts as (
  select
    id,
    row_number() over (
      partition by couple_id
      order by due_date nulls last, created_at
    ) - 1 as rn
  from public.debts
  where is_deleted = false
)
update public.debts d
set sort_order = rd.rn
from ranked_debts rd
where d.id = rd.id;

create index if not exists idx_funds_sort_order
  on public.funds(couple_id, sort_order)
  where is_deleted = false;

create index if not exists idx_debts_sort_order
  on public.debts(couple_id, sort_order)
  where is_deleted = false;
