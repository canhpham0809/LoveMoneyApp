drop policy if exists incomes_insert_policy on public.incomes;

create policy incomes_insert_policy
on public.incomes
for insert
with check (
  public.is_couple_member(couple_id)
  and (
    user_id = auth.uid()
    or (
      is_from_transfer = true
      and linked_transfer_id is not null
    )
  )
);