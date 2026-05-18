-- Create events table
create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples(id) on delete cascade,
  name text not null,
  start_date date not null,
  end_date date not null,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint events_unique_id_couple unique (id, couple_id)
);

-- Add event_id column to expenses table
alter table public.expenses
add column if not exists event_id uuid references public.events(id) on delete set null;

-- Add foreign key constraint to ensure event belongs to the same couple
alter table public.expenses
drop constraint if exists expenses_event_couple_fk,
add constraint expenses_event_couple_fk foreign key (event_id, couple_id)
  references public.events(id, couple_id) on delete set null;

-- Enable Row Level Security (RLS) on events
alter table public.events enable row level security;

-- Drop existing policies if they exist
drop policy if exists events_select_policy on public.events;
drop policy if exists events_insert_policy on public.events;
drop policy if exists events_update_policy on public.events;
drop policy if exists events_delete_policy on public.events;

-- Policies for public.events
create policy events_select_policy on public.events
  for select using (
    exists (
      select 1 from public.couple_members
      where couple_members.couple_id = events.couple_id
        and couple_members.user_id = auth.uid()
    )
  );

create policy events_insert_policy on public.events
  for insert with check (
    exists (
      select 1 from public.couple_members
      where couple_members.couple_id = events.couple_id
        and couple_members.user_id = auth.uid()
    )
  );

create policy events_update_policy on public.events
  for update using (
    exists (
      select 1 from public.couple_members
      where couple_members.couple_id = events.couple_id
        and couple_members.user_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from public.couple_members
      where couple_members.couple_id = events.couple_id
        and couple_members.user_id = auth.uid()
    )
  );

create policy events_delete_policy on public.events
  for delete using (
    exists (
      select 1 from public.couple_members
      where couple_members.couple_id = events.couple_id
        and couple_members.user_id = auth.uid()
    )
  );

-- Trigger for auto updated_at
drop trigger if exists trg_events_set_updated_at on public.events;
create trigger trg_events_set_updated_at
before update on public.events
for each row execute function public.set_updated_at();
