alter table public.funds
add column if not exists creator_user_id uuid references public.users(id) on delete set null;

update public.funds
set creator_user_id = coalesce(creator_user_id, updated_by)
where creator_user_id is null;

create index if not exists idx_funds_creator_user_id
on public.funds(creator_user_id);

create or replace function public.ensure_fund_creator_user_id()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' then
    if new.creator_user_id is null then
      new.creator_user_id = coalesce(auth.uid(), new.updated_by);
    end if;
  elsif tg_op = 'UPDATE' then
    new.creator_user_id = old.creator_user_id;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_funds_set_creator_user_id on public.funds;
create trigger trg_funds_set_creator_user_id
before insert or update on public.funds
for each row execute function public.ensure_fund_creator_user_id();
