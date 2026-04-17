alter table public.categories
  add column if not exists show_in_expense_form boolean not null default true;

alter table public.income_sources
  add column if not exists show_in_income_form boolean not null default true;

-- Hide system/generated categories from Expense create form.
update public.categories
set show_in_expense_form = false
where lower(name) in (
  'cho muon no',
  'xoa no dieu chinh'
);

-- Hide system/generated income sources from Income create form.
update public.income_sources
set show_in_income_form = false
where lower(name) in (
  'internal transfer',
  'rut quy',
  'xoa quy hoan tien',
  'nhan tien no',
  'thu hoi cho muon',
  'xoa cho muon dieu chinh'
);

create index if not exists idx_categories_expense_form_visible
  on public.categories(couple_id, show_in_expense_form)
  where is_deleted = false;

create index if not exists idx_income_sources_income_form_visible
  on public.income_sources(couple_id, show_in_income_form)
  where is_deleted = false;
