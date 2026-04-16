-- Add invite code for each couple and RPC to join a couple by code.

alter table public.couples
  add column if not exists invite_code text;

-- Backfill missing codes for existing rows.
update public.couples
set invite_code = upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8))
where invite_code is null;

alter table public.couples
  alter column invite_code set not null;

create unique index if not exists couples_invite_code_key
  on public.couples (invite_code);

create or replace function public.set_couple_invite_code()
returns trigger
language plpgsql
as $$
begin
  if new.invite_code is null or btrim(new.invite_code) = '' then
    new.invite_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
  else
    new.invite_code := upper(btrim(new.invite_code));
  end if;
  return new;
end;
$$;

drop trigger if exists trg_set_couple_invite_code on public.couples;
create trigger trg_set_couple_invite_code
before insert or update on public.couples
for each row execute function public.set_couple_invite_code();

create or replace function public.join_couple_by_code(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_couple_id uuid;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'UNAUTHENTICATED';
  end if;

  select c.id
    into v_couple_id
  from public.couples c
  where c.invite_code = upper(btrim(coalesce(p_code, '')))
  limit 1;

  if v_couple_id is null then
    raise exception 'INVALID_COUPLE_CODE';
  end if;

  -- One active couple per user.
  if exists (
    select 1
    from public.couple_members cm
    where cm.user_id = v_uid
      and cm.is_deleted = false
  ) then
    raise exception 'ALREADY_IN_COUPLE';
  end if;

  insert into public.couple_members (couple_id, user_id, joined_at)
  values (v_couple_id, v_uid, timezone('utc', now()));

  return v_couple_id;
end;
$$;

grant execute on function public.join_couple_by_code(text) to authenticated;
