-- Migration 009: tamanho comercial dos produtos.
-- Campos opcionais preservam produtos legados que ainda não possuem tamanho definido.

alter table public.products
  add column if not exists size_value numeric,
  add column if not exists size_unit text;

alter table public.products
  drop constraint if exists products_size_value_check;

alter table public.products
  add constraint products_size_value_check
  check (size_value is null or size_value > 0);

alter table public.products
  drop constraint if exists products_size_unit_check;

alter table public.products
  add constraint products_size_unit_check
  check (size_unit is null or size_unit in ('kg', 'g', 'l', 'ml', 'un'));

create index if not exists products_company_name_size_idx
  on public.products (company_id, name, size_value, size_unit)
  where active = true;
