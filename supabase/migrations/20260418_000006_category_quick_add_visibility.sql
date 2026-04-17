alter table public.categories
  add column if not exists show_in_quick_add boolean not null default true;

-- Hide system-generated debt adjustment categories from Quick Add tags.
update public.categories
set show_in_quick_add = false
where lower(name) in ('cho muon no', 'xoa no dieu chinh');

create index if not exists idx_categories_quick_add_visible
  on public.categories(couple_id, show_in_quick_add)
  where is_deleted = false;
