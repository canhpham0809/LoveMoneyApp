alter table public.transfers
  drop constraint if exists transfers_wallets_not_same_chk;

alter table public.transfers
  drop constraint if exists transfers_from_wallet_couple_fk;

alter table public.transfers
  drop constraint if exists transfers_to_wallet_couple_fk;

alter table public.incomes
  drop constraint if exists incomes_wallet_couple_fk;

alter table public.transfers
  alter column from_wallet_id drop not null,
  alter column to_wallet_id drop not null;

alter table public.incomes
  alter column wallet_id drop not null;
