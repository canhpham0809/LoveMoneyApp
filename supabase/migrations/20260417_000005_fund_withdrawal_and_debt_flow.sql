alter table public.fund_contributions
  add column if not exists contribution_type text not null default 'contribution'
  check (contribution_type in ('contribution', 'withdrawal')),
  add column if not exists linked_income_id uuid;

alter table public.fund_contributions
  drop constraint if exists fund_contributions_linked_income_fk;

alter table public.fund_contributions
  add constraint fund_contributions_linked_income_fk
  foreign key (linked_income_id, couple_id)
  references public.incomes(id, couple_id)
  on delete set null
  deferrable initially deferred;

create index if not exists idx_fund_contributions_type
  on public.fund_contributions(couple_id, contribution_type)
  where is_deleted = false;

alter table public.debts
  add column if not exists debt_kind text not null default 'debt'
  check (debt_kind in ('debt', 'lend')),
  add column if not exists record_to_income boolean not null default false,
  add column if not exists linked_income_id uuid,
  add column if not exists linked_expense_id uuid;

alter table public.debts
  drop constraint if exists debts_linked_income_fk;

alter table public.debts
  add constraint debts_linked_income_fk
  foreign key (linked_income_id, couple_id)
  references public.incomes(id, couple_id)
  on delete set null
  deferrable initially deferred;

alter table public.debts
  drop constraint if exists debts_linked_expense_fk;

alter table public.debts
  add constraint debts_linked_expense_fk
  foreign key (linked_expense_id, couple_id)
  references public.expenses(id, couple_id)
  on delete set null
  deferrable initially deferred;

alter table public.debt_payments
  add column if not exists linked_income_id uuid;

alter table public.debt_payments
  drop constraint if exists debt_payments_linked_income_fk;

alter table public.debt_payments
  add constraint debt_payments_linked_income_fk
  foreign key (linked_income_id, couple_id)
  references public.incomes(id, couple_id)
  on delete set null
  deferrable initially deferred;

create index if not exists idx_debts_kind
  on public.debts(couple_id, debt_kind)
  where is_deleted = false;
