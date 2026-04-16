-- Family Cashbook Supabase Schema
-- Generated from docs/03-engineering/database_schema.md

begin;

create extension if not exists pgcrypto;
create extension if not exists citext;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  -- email is cached from auth.users; not authoritative. Nullable to support OAuth providers.
  email citext,
  display_name text not null,
  role_label text,
  avatar_url text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.couples (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  currency text not null default 'VND' check (char_length(currency) between 3 and 8),
  language text not null default 'vi',
  monthly_budget_amount numeric(14,2) check (monthly_budget_amount is null or monthly_budget_amount >= 0),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.couple_members (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  joined_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  updated_by uuid references public.users(id) on delete set null,
  is_deleted boolean not null default false,
  deleted_at timestamptz,
  constraint couple_members_unique_couple_user unique (couple_id, user_id),
  constraint couple_members_deleted_state_chk check (
    (is_deleted = false and deleted_at is null)
    or (is_deleted = true and deleted_at is not null)
  )
);

create or replace function public.enforce_couple_member_limit()
returns trigger
language plpgsql
as $$
declare
  active_count integer;
begin
  if new.is_deleted = false then
    select count(*)
      into active_count
    from public.couple_members cm
    where cm.couple_id = new.couple_id
      and cm.is_deleted = false
      and cm.id <> coalesce(new.id, '00000000-0000-0000-0000-000000000000'::uuid);

    if active_count >= 2 then
      raise exception 'A couple can only have 2 active members.';
    end if;
  end if;

  return new;
end;
$$;

create trigger trg_couple_members_limit
before insert or update on public.couple_members
for each row
execute function public.enforce_couple_member_limit();

create or replace function public.is_couple_member(target_couple_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.couple_members cm
    where cm.couple_id = target_couple_id
      and cm.user_id = auth.uid()
      and cm.is_deleted = false
  );
$$;

create or replace function public.can_access_user(target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.couple_members me
    join public.couple_members other
      on other.couple_id = me.couple_id
     and other.is_deleted = false
    where me.user_id = auth.uid()
      and me.is_deleted = false
      and other.user_id = target_user_id
  );
$$;

-- ---------------------------------------------------------------------------
-- Fix #2: After a couple is created, auto-enroll the creator as first member.
-- auth.uid() is available inside triggers called from authenticated sessions.
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_couple()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Guard: auth.uid() is null when called from service role / seed scripts.
  if auth.uid() is not null then
    insert into public.couple_members (couple_id, user_id, joined_at)
    values (new.id, auth.uid(), timezone('utc', now()));
  end if;
  return new;
end;
$$;

create trigger trg_on_couple_created
after insert on public.couples
for each row execute function public.handle_new_couple();

create table if not exists public.wallets (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  name text not null,
  type text not null check (type in ('cash', 'bank', 'ewallet', 'other')),
  -- Snapshot field only. Not auto-updated. Use wallet_balances view for accurate computed balance.
  balance numeric(14,2) not null default 0 check (balance >= 0),
  currency text not null default 'VND',
  is_default boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  updated_by uuid references public.users(id) on delete set null,
  is_deleted boolean not null default false,
  deleted_at timestamptz,
  constraint wallets_unique_id_couple unique (id, couple_id),
  constraint wallets_deleted_state_chk check (
    (is_deleted = false and deleted_at is null)
    or (is_deleted = true and deleted_at is not null)
  )
);

create unique index if not exists ux_wallets_default_per_couple
  on public.wallets(couple_id)
  where is_default = true and is_active = true and is_deleted = false;

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  name text not null,
  icon text,
  color text,
  budget_limit numeric(14,2) check (budget_limit is null or budget_limit >= 0),
  sort_order integer,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  updated_by uuid references public.users(id) on delete set null,
  is_deleted boolean not null default false,
  deleted_at timestamptz,
  constraint categories_unique_id_couple unique (id, couple_id),
  constraint categories_deleted_state_chk check (
    (is_deleted = false and deleted_at is null)
    or (is_deleted = true and deleted_at is not null)
  )
);

create table if not exists public.income_sources (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  name text not null,
  icon text,
  type text not null check (type in ('salary', 'investment', 'bonus', 'freelance', 'rental', 'gift', 'other')),
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  updated_by uuid references public.users(id) on delete set null,
  is_deleted boolean not null default false,
  deleted_at timestamptz,
  constraint income_sources_unique_id_couple unique (id, couple_id),
  constraint income_sources_deleted_state_chk check (
    (is_deleted = false and deleted_at is null)
    or (is_deleted = true and deleted_at is not null)
  )
);

create table if not exists public.funds (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  name text not null,
  icon text,
  target_amount numeric(14,2) check (target_amount is null or target_amount >= 0),
  current_amount numeric(14,2) not null default 0 check (current_amount >= 0),
  deadline date,
  color text,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  updated_by uuid references public.users(id) on delete set null,
  is_deleted boolean not null default false,
  deleted_at timestamptz,
  constraint funds_unique_id_couple unique (id, couple_id),
  constraint funds_deleted_state_chk check (
    (is_deleted = false and deleted_at is null)
    or (is_deleted = true and deleted_at is not null)
  )
);

create table if not exists public.debt_types (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  updated_by uuid references public.users(id) on delete set null,
  is_deleted boolean not null default false,
  deleted_at timestamptz,
  constraint debt_types_unique_id_couple unique (id, couple_id),
  constraint debt_types_deleted_state_chk check (
    (is_deleted = false and deleted_at is null)
    or (is_deleted = true and deleted_at is not null)
  )
);

create table if not exists public.monthly_budgets (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  -- Store first day of month e.g. 2026-04-01. Supports range queries and proper sorting.
  month date not null,
  amount numeric(14,2) not null check (amount >= 0),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  updated_by uuid references public.users(id) on delete set null,
  is_deleted boolean not null default false,
  deleted_at timestamptz,
  constraint monthly_budgets_deleted_state_chk check (
    (is_deleted = false and deleted_at is null)
    or (is_deleted = true and deleted_at is not null)
  )
);

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  user_id uuid not null,
  wallet_id uuid not null,
  category_id uuid not null,
  category_name text,
  category_icon text,
  amount numeric(14,2) not null check (amount > 0),
  description text,
  date date not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  updated_by uuid references public.users(id) on delete set null,
  is_deleted boolean not null default false,
  deleted_at timestamptz,
  constraint expenses_unique_id_couple unique (id, couple_id),
  constraint expenses_deleted_state_chk check (
    (is_deleted = false and deleted_at is null)
    or (is_deleted = true and deleted_at is not null)
  ),
  constraint expenses_user_couple_fk foreign key (user_id, couple_id)
    references public.couple_members(user_id, couple_id) on delete restrict,
  constraint expenses_wallet_couple_fk foreign key (wallet_id, couple_id)
    references public.wallets(id, couple_id) on delete restrict,
  constraint expenses_category_couple_fk foreign key (category_id, couple_id)
    references public.categories(id, couple_id) on delete restrict
);

create table if not exists public.transfers (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  from_user_id uuid not null,
  to_user_id uuid not null,
  from_wallet_id uuid not null,
  to_wallet_id uuid not null,
  amount numeric(14,2) not null check (amount > 0),
  note text,
  linked_income_id uuid,
  date date not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  updated_by uuid references public.users(id) on delete set null,
  is_deleted boolean not null default false,
  deleted_at timestamptz,
  constraint transfers_unique_id_couple unique (id, couple_id),
  constraint transfers_wallets_not_same_chk check (from_wallet_id <> to_wallet_id),
  constraint transfers_users_not_same_chk check (from_user_id <> to_user_id),
  constraint transfers_deleted_state_chk check (
    (is_deleted = false and deleted_at is null)
    or (is_deleted = true and deleted_at is not null)
  ),
  constraint transfers_from_user_couple_fk foreign key (from_user_id, couple_id)
    references public.couple_members(user_id, couple_id) on delete restrict,
  constraint transfers_to_user_couple_fk foreign key (to_user_id, couple_id)
    references public.couple_members(user_id, couple_id) on delete restrict,
  constraint transfers_from_wallet_couple_fk foreign key (from_wallet_id, couple_id)
    references public.wallets(id, couple_id) on delete restrict,
  constraint transfers_to_wallet_couple_fk foreign key (to_wallet_id, couple_id)
    references public.wallets(id, couple_id) on delete restrict
);

create table if not exists public.incomes (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  user_id uuid not null,
  wallet_id uuid not null,
  income_source_id uuid not null,
  amount numeric(14,2) not null check (amount > 0),
  description text,
  is_from_transfer boolean not null default false,
  linked_transfer_id uuid,
  date date not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  updated_by uuid references public.users(id) on delete set null,
  is_deleted boolean not null default false,
  deleted_at timestamptz,
  constraint incomes_unique_id_couple unique (id, couple_id),
  constraint incomes_transfer_link_chk check (
    (is_from_transfer = true and linked_transfer_id is not null)
    or (is_from_transfer = false)
  ),
  constraint incomes_deleted_state_chk check (
    (is_deleted = false and deleted_at is null)
    or (is_deleted = true and deleted_at is not null)
  ),
  constraint incomes_user_couple_fk foreign key (user_id, couple_id)
    references public.couple_members(user_id, couple_id) on delete restrict,
  constraint incomes_wallet_couple_fk foreign key (wallet_id, couple_id)
    references public.wallets(id, couple_id) on delete restrict,
  constraint incomes_income_source_couple_fk foreign key (income_source_id, couple_id)
    references public.income_sources(id, couple_id) on delete restrict
);

create table if not exists public.fund_contributions (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  user_id uuid not null,
  fund_id uuid not null,
  wallet_id uuid not null,
  amount numeric(14,2) not null check (amount > 0),
  note text,
  date date not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  updated_by uuid references public.users(id) on delete set null,
  is_deleted boolean not null default false,
  deleted_at timestamptz,
  constraint fund_contributions_unique_id_couple unique (id, couple_id),
  constraint fund_contributions_deleted_state_chk check (
    (is_deleted = false and deleted_at is null)
    or (is_deleted = true and deleted_at is not null)
  ),
  constraint fund_contributions_user_couple_fk foreign key (user_id, couple_id)
    references public.couple_members(user_id, couple_id) on delete restrict,
  constraint fund_contributions_fund_couple_fk foreign key (fund_id, couple_id)
    references public.funds(id, couple_id) on delete restrict,
  constraint fund_contributions_wallet_couple_fk foreign key (wallet_id, couple_id)
    references public.wallets(id, couple_id) on delete restrict
);

create table if not exists public.debts (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  user_id uuid not null,
  debt_type_id uuid not null,
  name text not null,
  original_amount numeric(14,2) not null check (original_amount > 0),
  remaining_amount numeric(14,2) not null check (remaining_amount >= 0),
  creditor_name text not null,
  start_date date not null,
  due_date date,
  reminder_days_before integer check (reminder_days_before is null or reminder_days_before >= 0),
  note text,
  is_closed boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  updated_by uuid references public.users(id) on delete set null,
  is_deleted boolean not null default false,
  deleted_at timestamptz,
  constraint debts_unique_id_couple unique (id, couple_id),
  constraint debts_deleted_state_chk check (
    (is_deleted = false and deleted_at is null)
    or (is_deleted = true and deleted_at is not null)
  ),
  constraint debts_amounts_chk check (remaining_amount <= original_amount),
  constraint debts_user_couple_fk foreign key (user_id, couple_id)
    references public.couple_members(user_id, couple_id) on delete restrict,
  constraint debts_debt_type_couple_fk foreign key (debt_type_id, couple_id)
    references public.debt_types(id, couple_id) on delete restrict
);

create table if not exists public.debt_payments (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  debt_id uuid not null,
  wallet_id uuid not null,
  amount numeric(14,2) not null check (amount > 0),
  date date not null,
  note text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  updated_by uuid references public.users(id) on delete set null,
  is_deleted boolean not null default false,
  deleted_at timestamptz,
  constraint debt_payments_unique_id_couple unique (id, couple_id),
  constraint debt_payments_deleted_state_chk check (
    (is_deleted = false and deleted_at is null)
    or (is_deleted = true and deleted_at is not null)
  ),
  constraint debt_payments_debt_couple_fk foreign key (debt_id, couple_id)
    references public.debts(id, couple_id) on delete cascade,
  constraint debt_payments_wallet_couple_fk foreign key (wallet_id, couple_id)
    references public.wallets(id, couple_id) on delete restrict
);

alter table public.incomes
  add constraint incomes_linked_transfer_fk
  foreign key (linked_transfer_id, couple_id)
  references public.transfers(id, couple_id)
  on delete set null
  deferrable initially deferred;

alter table public.transfers
  add constraint transfers_linked_income_fk
  foreign key (linked_income_id, couple_id)
  references public.incomes(id, couple_id)
  on delete set null
  deferrable initially deferred;

create unique index if not exists ux_monthly_budgets_couple_month_active
  on public.monthly_budgets (couple_id, month)
  where is_deleted = false;

-- ---------------------------------------------------------------------------
-- Fix #5: Partial unique indexes for soft-deletable name-scoped uniqueness.
-- Allows re-creating a deleted record without hitting duplicate key errors.
-- ---------------------------------------------------------------------------
create unique index if not exists ux_categories_name_per_couple
  on public.categories(couple_id, name) where is_deleted = false;

create unique index if not exists ux_income_sources_name_per_couple
  on public.income_sources(couple_id, name) where is_deleted = false;

create unique index if not exists ux_funds_name_per_couple
  on public.funds(couple_id, name) where is_deleted = false;

create unique index if not exists ux_debt_types_name_per_couple
  on public.debt_types(couple_id, name) where is_deleted = false;

-- ---------------------------------------------------------------------------
-- wallet_balances: Realtime computed balance view.
-- wallets.balance is a snapshot field and NOT auto-updated by the database.
-- security_invoker = true ensures the caller's RLS policies are enforced.
-- ---------------------------------------------------------------------------
create or replace view public.wallet_balances
with (security_invoker = true)
as
select
  w.id                                                       as wallet_id,
  w.couple_id,
  w.name,
  coalesce(inc.total,    0)
  - coalesce(exp.total,    0)
  - coalesce(tr_out.total, 0)
  + coalesce(tr_in.total,  0)                               as computed_balance
from public.wallets w
left join (
  select wallet_id, sum(amount) as total
  from public.incomes
  where is_deleted = false
  group by wallet_id
) inc on inc.wallet_id = w.id
left join (
  select wallet_id, sum(amount) as total
  from public.expenses
  where is_deleted = false
  group by wallet_id
) exp on exp.wallet_id = w.id
left join (
  select from_wallet_id as wallet_id, sum(amount) as total
  from public.transfers
  where is_deleted = false
  group by from_wallet_id
) tr_out on tr_out.wallet_id = w.id
left join (
  select to_wallet_id as wallet_id, sum(amount) as total
  from public.transfers
  where is_deleted = false
  group by to_wallet_id
) tr_in on tr_in.wallet_id = w.id
where w.is_deleted = false;

create index if not exists idx_couple_members_couple_id on public.couple_members(couple_id);
create index if not exists idx_couple_members_user_id on public.couple_members(user_id);

create index if not exists idx_wallets_couple_id on public.wallets(couple_id);
create index if not exists idx_wallets_active on public.wallets(couple_id, is_active) where is_deleted = false;

create index if not exists idx_categories_couple_id on public.categories(couple_id);
create index if not exists idx_categories_active on public.categories(couple_id, is_active) where is_deleted = false;

create index if not exists idx_income_sources_couple_id on public.income_sources(couple_id);
create index if not exists idx_income_sources_active on public.income_sources(couple_id, is_active) where is_deleted = false;

create index if not exists idx_funds_couple_id on public.funds(couple_id);
create index if not exists idx_funds_active on public.funds(couple_id, is_active) where is_deleted = false;

create index if not exists idx_debt_types_couple_id on public.debt_types(couple_id);
create index if not exists idx_debt_types_active on public.debt_types(couple_id, is_active) where is_deleted = false;

create index if not exists idx_expenses_couple_date on public.expenses(couple_id, date desc);
create index if not exists idx_expenses_wallet_id on public.expenses(wallet_id);
create index if not exists idx_expenses_category_id on public.expenses(category_id);
create index if not exists idx_expenses_user_id on public.expenses(user_id);
create index if not exists idx_expenses_not_deleted on public.expenses(couple_id, is_deleted, date desc);

-- Month aggregation indexes for dashboard queries.
-- Use immutable expressions (no generated columns) for Supabase/Postgres compatibility.
create index if not exists idx_expenses_month
on public.expenses(
  couple_id,
  make_date(extract(year from date)::int, extract(month from date)::int, 1)
);

create index if not exists idx_incomes_month
on public.incomes(
  couple_id,
  make_date(extract(year from date)::int, extract(month from date)::int, 1)
);

create index if not exists idx_transfers_month
on public.transfers(
  couple_id,
  make_date(extract(year from date)::int, extract(month from date)::int, 1)
);

create index if not exists idx_incomes_couple_date on public.incomes(couple_id, date desc);
create index if not exists idx_incomes_wallet_id on public.incomes(wallet_id);
create index if not exists idx_incomes_user_id on public.incomes(user_id);
create index if not exists idx_incomes_linked_transfer_id on public.incomes(linked_transfer_id) where linked_transfer_id is not null;

create index if not exists idx_transfers_couple_date on public.transfers(couple_id, date desc);
create index if not exists idx_transfers_from_wallet_id on public.transfers(from_wallet_id);
create index if not exists idx_transfers_to_wallet_id on public.transfers(to_wallet_id);
create index if not exists idx_transfers_from_user_id on public.transfers(from_user_id);
create index if not exists idx_transfers_to_user_id on public.transfers(to_user_id);
create index if not exists idx_transfers_linked_income_id on public.transfers(linked_income_id) where linked_income_id is not null;

create index if not exists idx_fund_contributions_fund_date on public.fund_contributions(fund_id, date desc);
create index if not exists idx_fund_contributions_couple_date on public.fund_contributions(couple_id, date desc);
create index if not exists idx_fund_contributions_wallet_id on public.fund_contributions(wallet_id);

create index if not exists idx_debts_couple_due_date on public.debts(couple_id, due_date);
create index if not exists idx_debts_user_id on public.debts(user_id);
create index if not exists idx_debts_open on public.debts(couple_id, is_closed) where is_deleted = false;

create index if not exists idx_debt_payments_debt_date on public.debt_payments(debt_id, date desc);
create index if not exists idx_debt_payments_couple_date on public.debt_payments(couple_id, date desc);
create index if not exists idx_debt_payments_wallet_id on public.debt_payments(wallet_id);

create trigger trg_users_set_updated_at
before update on public.users
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Fix #1: Sync auth.users → public.users on every new signup.
-- Runs as security definer so it can write to public.users regardless of RLS.
-- display_name falls back to the part before '@' when not provided.
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, email, display_name)
  values (
    new.id,
    new.email,
    coalesce(
      new.raw_user_meta_data->>'display_name',
      new.raw_user_meta_data->>'full_name',
      split_part(coalesce(new.email, new.id::text), '@', 1)
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger trg_on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();

create trigger trg_couples_set_updated_at
before update on public.couples
for each row execute function public.set_updated_at();

create trigger trg_couple_members_set_updated_at
before update on public.couple_members
for each row execute function public.set_updated_at();

create trigger trg_wallets_set_updated_at
before update on public.wallets
for each row execute function public.set_updated_at();

create trigger trg_categories_set_updated_at
before update on public.categories
for each row execute function public.set_updated_at();

create trigger trg_income_sources_set_updated_at
before update on public.income_sources
for each row execute function public.set_updated_at();

create trigger trg_funds_set_updated_at
before update on public.funds
for each row execute function public.set_updated_at();

create trigger trg_debt_types_set_updated_at
before update on public.debt_types
for each row execute function public.set_updated_at();

create trigger trg_monthly_budgets_set_updated_at
before update on public.monthly_budgets
for each row execute function public.set_updated_at();

create trigger trg_expenses_set_updated_at
before update on public.expenses
for each row execute function public.set_updated_at();

create trigger trg_incomes_set_updated_at
before update on public.incomes
for each row execute function public.set_updated_at();

create trigger trg_transfers_set_updated_at
before update on public.transfers
for each row execute function public.set_updated_at();

create trigger trg_fund_contributions_set_updated_at
before update on public.fund_contributions
for each row execute function public.set_updated_at();

create trigger trg_debts_set_updated_at
before update on public.debts
for each row execute function public.set_updated_at();

create trigger trg_debt_payments_set_updated_at
before update on public.debt_payments
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Fix #4: Stamp updated_by = auth.uid() on every insert and update.
-- Applied to all tables that carry the updated_by audit column.
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_by()
returns trigger
language plpgsql
as $$
begin
  -- Preserves explicit values set by admin/service roles when auth.uid() is null.
  new.updated_by = coalesce(auth.uid(), new.updated_by);
  return new;
end;
$$;

create trigger trg_couple_members_set_updated_by
before insert or update on public.couple_members
for each row execute function public.set_updated_by();

create trigger trg_wallets_set_updated_by
before insert or update on public.wallets
for each row execute function public.set_updated_by();

create trigger trg_categories_set_updated_by
before insert or update on public.categories
for each row execute function public.set_updated_by();

create trigger trg_income_sources_set_updated_by
before insert or update on public.income_sources
for each row execute function public.set_updated_by();

create trigger trg_funds_set_updated_by
before insert or update on public.funds
for each row execute function public.set_updated_by();

create trigger trg_debt_types_set_updated_by
before insert or update on public.debt_types
for each row execute function public.set_updated_by();

create trigger trg_monthly_budgets_set_updated_by
before insert or update on public.monthly_budgets
for each row execute function public.set_updated_by();

create trigger trg_expenses_set_updated_by
before insert or update on public.expenses
for each row execute function public.set_updated_by();

create trigger trg_incomes_set_updated_by
before insert or update on public.incomes
for each row execute function public.set_updated_by();

create trigger trg_transfers_set_updated_by
before insert or update on public.transfers
for each row execute function public.set_updated_by();

create trigger trg_fund_contributions_set_updated_by
before insert or update on public.fund_contributions
for each row execute function public.set_updated_by();

create trigger trg_debts_set_updated_by
before insert or update on public.debts
for each row execute function public.set_updated_by();

create trigger trg_debt_payments_set_updated_by
before insert or update on public.debt_payments
for each row execute function public.set_updated_by();

alter table public.users enable row level security;
alter table public.couples enable row level security;
alter table public.couple_members enable row level security;
alter table public.wallets enable row level security;
alter table public.categories enable row level security;
alter table public.income_sources enable row level security;
alter table public.funds enable row level security;
alter table public.debt_types enable row level security;
alter table public.monthly_budgets enable row level security;
alter table public.expenses enable row level security;
alter table public.incomes enable row level security;
alter table public.transfers enable row level security;
alter table public.fund_contributions enable row level security;
alter table public.debts enable row level security;
alter table public.debt_payments enable row level security;

create policy users_select_policy
on public.users
for select
using (id = auth.uid() or public.can_access_user(id));

create policy users_insert_policy
on public.users
for insert
with check (id = auth.uid());

create policy users_update_policy
on public.users
for update
using (id = auth.uid())
with check (id = auth.uid());

create policy couples_select_policy
on public.couples
for select
using (public.is_couple_member(id));

-- Fix #7 / Fix #8: Restrict couple creation to authenticated users.
-- The trg_on_couple_created trigger guarantees creator becomes the first member,
-- so is_couple_member(id) would always be false here — auth.uid() is the correct guard.
create policy couples_insert_policy
on public.couples
for insert
with check (auth.uid() is not null);

create policy couples_update_policy
on public.couples
for update
using (public.is_couple_member(id))
with check (public.is_couple_member(id));

create policy couples_delete_policy
on public.couples
for delete
using (public.is_couple_member(id));

create policy couple_members_select_policy
on public.couple_members
for select
using (public.is_couple_member(couple_id));

create policy couple_members_insert_policy
on public.couple_members
for insert
with check (
  auth.uid() is not null
  and (
    public.is_couple_member(couple_id)
    or (
      user_id = auth.uid()
      and (
        select count(*)
        from public.couple_members cm
        where cm.couple_id = couple_members.couple_id
          and cm.is_deleted = false
      ) = 0
    )
  )
);

create policy couple_members_update_policy
on public.couple_members
for update
using (public.is_couple_member(couple_id))
with check (public.is_couple_member(couple_id));

create policy couple_members_delete_policy
on public.couple_members
for delete
using (public.is_couple_member(couple_id));

create policy wallets_select_policy
on public.wallets
for select
using (public.is_couple_member(couple_id));

create policy wallets_insert_policy
on public.wallets
for insert
with check (public.is_couple_member(couple_id));

create policy wallets_update_policy
on public.wallets
for update
using (public.is_couple_member(couple_id))
with check (public.is_couple_member(couple_id));

create policy wallets_delete_policy
on public.wallets
for delete
using (public.is_couple_member(couple_id));

create policy categories_select_policy
on public.categories
for select
using (public.is_couple_member(couple_id));

create policy categories_insert_policy
on public.categories
for insert
with check (public.is_couple_member(couple_id));

create policy categories_update_policy
on public.categories
for update
using (public.is_couple_member(couple_id))
with check (public.is_couple_member(couple_id));

create policy categories_delete_policy
on public.categories
for delete
using (public.is_couple_member(couple_id));

create policy income_sources_select_policy
on public.income_sources
for select
using (public.is_couple_member(couple_id));

create policy income_sources_insert_policy
on public.income_sources
for insert
with check (public.is_couple_member(couple_id));

create policy income_sources_update_policy
on public.income_sources
for update
using (public.is_couple_member(couple_id))
with check (public.is_couple_member(couple_id));

create policy income_sources_delete_policy
on public.income_sources
for delete
using (public.is_couple_member(couple_id));

create policy funds_select_policy
on public.funds
for select
using (public.is_couple_member(couple_id));

create policy funds_insert_policy
on public.funds
for insert
with check (public.is_couple_member(couple_id));

create policy funds_update_policy
on public.funds
for update
using (public.is_couple_member(couple_id))
with check (public.is_couple_member(couple_id));

create policy funds_delete_policy
on public.funds
for delete
using (public.is_couple_member(couple_id));

create policy debt_types_select_policy
on public.debt_types
for select
using (public.is_couple_member(couple_id));

create policy debt_types_insert_policy
on public.debt_types
for insert
with check (public.is_couple_member(couple_id));

create policy debt_types_update_policy
on public.debt_types
for update
using (public.is_couple_member(couple_id))
with check (public.is_couple_member(couple_id));

create policy debt_types_delete_policy
on public.debt_types
for delete
using (public.is_couple_member(couple_id));

create policy monthly_budgets_select_policy
on public.monthly_budgets
for select
using (public.is_couple_member(couple_id));

create policy monthly_budgets_insert_policy
on public.monthly_budgets
for insert
with check (public.is_couple_member(couple_id));

create policy monthly_budgets_update_policy
on public.monthly_budgets
for update
using (public.is_couple_member(couple_id))
with check (public.is_couple_member(couple_id));

create policy monthly_budgets_delete_policy
on public.monthly_budgets
for delete
using (public.is_couple_member(couple_id));

create policy expenses_select_policy
on public.expenses
for select
using (public.is_couple_member(couple_id));

create policy expenses_insert_policy
on public.expenses
for insert
with check (
  public.is_couple_member(couple_id)
  and user_id = auth.uid()
);

create policy expenses_update_policy
on public.expenses
for update
using (public.is_couple_member(couple_id))
with check (public.is_couple_member(couple_id));

create policy expenses_delete_policy
on public.expenses
for delete
using (public.is_couple_member(couple_id));

create policy incomes_select_policy
on public.incomes
for select
using (public.is_couple_member(couple_id));

create policy incomes_insert_policy
on public.incomes
for insert
with check (
  public.is_couple_member(couple_id)
  and user_id = auth.uid()
);

create policy incomes_update_policy
on public.incomes
for update
using (public.is_couple_member(couple_id))
with check (public.is_couple_member(couple_id));

create policy incomes_delete_policy
on public.incomes
for delete
using (public.is_couple_member(couple_id));

create policy transfers_select_policy
on public.transfers
for select
using (public.is_couple_member(couple_id));

create policy transfers_insert_policy
on public.transfers
for insert
with check (
  public.is_couple_member(couple_id)
  and from_user_id = auth.uid()
);

create policy transfers_update_policy
on public.transfers
for update
using (public.is_couple_member(couple_id))
with check (public.is_couple_member(couple_id));

create policy transfers_delete_policy
on public.transfers
for delete
using (public.is_couple_member(couple_id));

create policy fund_contributions_select_policy
on public.fund_contributions
for select
using (public.is_couple_member(couple_id));

create policy fund_contributions_insert_policy
on public.fund_contributions
for insert
with check (
  public.is_couple_member(couple_id)
  and user_id = auth.uid()
);

create policy fund_contributions_update_policy
on public.fund_contributions
for update
using (public.is_couple_member(couple_id))
with check (public.is_couple_member(couple_id));

create policy fund_contributions_delete_policy
on public.fund_contributions
for delete
using (public.is_couple_member(couple_id));

create policy debts_select_policy
on public.debts
for select
using (public.is_couple_member(couple_id));

create policy debts_insert_policy
on public.debts
for insert
with check (
  public.is_couple_member(couple_id)
  and user_id = auth.uid()
);

create policy debts_update_policy
on public.debts
for update
using (public.is_couple_member(couple_id))
with check (public.is_couple_member(couple_id));

create policy debts_delete_policy
on public.debts
for delete
using (public.is_couple_member(couple_id));

create policy debt_payments_select_policy
on public.debt_payments
for select
using (public.is_couple_member(couple_id));

create policy debt_payments_insert_policy
on public.debt_payments
for insert
with check (public.is_couple_member(couple_id));

create policy debt_payments_update_policy
on public.debt_payments
for update
using (public.is_couple_member(couple_id))
with check (public.is_couple_member(couple_id));

create policy debt_payments_delete_policy
on public.debt_payments
for delete
using (public.is_couple_member(couple_id));

commit;
