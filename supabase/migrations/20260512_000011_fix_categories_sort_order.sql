-- Set default and not null for categories sort_order
-- First, populate NULL values with sequential numbers per couple
with ranked_categories as (
  select
    id,
    row_number() over (
      partition by couple_id
      order by coalesce(sort_order, 0), created_at, name, id
    ) - 1 as rn
  from public.categories
  where is_deleted = false
)
update public.categories c
set sort_order = rc.rn
from ranked_categories rc
where c.id = rc.id
and c.is_deleted = false
and c.sort_order is null;

-- Alter column to add NOT NULL and DEFAULT
alter table public.categories
  alter column sort_order set not null,
  alter column sort_order set default 0;

-- Create index for efficient sorting
create index if not exists idx_categories_sort_order
  on public.categories(couple_id, sort_order)
  where is_deleted = false;
