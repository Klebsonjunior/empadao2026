-- Data operacional dos movimentos para relatórios por período.

alter table public.inventory_movements
  add column if not exists movement_date date;

update public.inventory_movements
  set movement_date = created_at::date
  where movement_date is null;

create index if not exists inventory_movements_user_date_idx
  on public.inventory_movements (user_id, movement_date desc);
