-- Migration 006: multiempresa por domínio e associação de utilizadores.
-- NÃO aplicar sem backup e validação das contagens legadas.
-- Não faz DROP de tabelas nem remove registos.

create table if not exists public.companies (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9-]+$'),
  name text not null check (char_length(trim(name)) > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.company_domains (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  hostname text not null unique check (hostname = lower(hostname) and hostname !~ '[/:]'),
  is_primary boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.company_memberships (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'user' check (role in ('administrator', 'user')),
  created_at timestamptz not null default now(),
  unique (company_id, user_id)
);

create index if not exists company_domains_company_idx on public.company_domains(company_id);
create index if not exists company_memberships_user_idx on public.company_memberships(user_id);
create index if not exists company_memberships_company_idx on public.company_memberships(company_id);

insert into public.companies (slug, name)
values ('empadao', 'Empadão'), ('brigadeiros', 'Brigadeiros')
on conflict (slug) do update set name = excluded.name, updated_at = now();

insert into public.company_domains (company_id, hostname, is_primary)
select c.id, v.hostname, true
from (values ('empadao', 'empadao2026.vercel.app'), ('brigadeiros', 'brigadeirogourmet.vercel.app')) as v(slug, hostname)
join public.companies c on c.slug = v.slug
on conflict (hostname) do update set company_id = excluded.company_id, is_primary = true;

insert into public.company_memberships (company_id, user_id, role)
select c.id, u.id, v.role
from (values
  ('empadao', 'klebson-junior@hotmail.com', 'administrator'),
  ('empadao', 'sil.balena21@gmail.com', 'user'),
  ('brigadeiros', 'contato.jejr@gmail.com', 'administrator')
) as v(slug, email, role)
join public.companies c on c.slug = v.slug
join auth.users u on lower(u.email) = lower(v.email)
on conflict (company_id, user_id) do update set role = excluded.role;

-- Todas as tabelas do produto de gestão recebem o contexto empresarial.
alter table public.ingredients add column if not exists company_id uuid;
alter table public.ingredients add column if not exists created_by_user_id uuid;
alter table public.purchases add column if not exists company_id uuid;
alter table public.purchases add column if not exists created_by_user_id uuid;
alter table public.products add column if not exists company_id uuid;
alter table public.products add column if not exists created_by_user_id uuid;
alter table public.recipes add column if not exists company_id uuid;
alter table public.recipes add column if not exists created_by_user_id uuid;
alter table public.recipe_items add column if not exists company_id uuid;
alter table public.recipe_items add column if not exists created_by_user_id uuid;
alter table public.production_batches add column if not exists company_id uuid;
alter table public.production_batches add column if not exists created_by_user_id uuid;
alter table public.inventory_movements add column if not exists company_id uuid;
alter table public.inventory_movements add column if not exists created_by_user_id uuid;
alter table public.sales add column if not exists company_id uuid;
alter table public.sales add column if not exists created_by_user_id uuid;
alter table public.sale_items add column if not exists company_id uuid;
alter table public.sale_items add column if not exists created_by_user_id uuid;
alter table public.suppliers add column if not exists company_id uuid;
alter table public.suppliers add column if not exists created_by_user_id uuid;
alter table public.purchase_batches add column if not exists company_id uuid;
alter table public.purchase_batches add column if not exists created_by_user_id uuid;
alter table public.operating_expenses add column if not exists company_id uuid;
alter table public.operating_expenses add column if not exists created_by_user_id uuid;

-- Backfill explícito por utilizador legado. Se surgir outro autor, a validação abaixo interrompe a migration.
do $$
declare
  empadao_id uuid;
  brigadeiros_id uuid;
  klebson_id uuid;
  contato_id uuid;
begin
  select id into empadao_id from public.companies where slug = 'empadao';
  select id into brigadeiros_id from public.companies where slug = 'brigadeiros';
  select id into klebson_id from auth.users where lower(email) = 'klebson-junior@hotmail.com';
  select id into contato_id from auth.users where lower(email) = 'contato.jejr@gmail.com';

  if empadao_id is null or brigadeiros_id is null or klebson_id is null or contato_id is null then
    raise exception 'Migration stopped: expected companies or legacy users were not found';
  end if;

  update public.ingredients set company_id = case when user_id = klebson_id then empadao_id when user_id = contato_id then brigadeiros_id else company_id end, created_by_user_id = coalesce(created_by_user_id, user_id) where company_id is null;
  update public.purchases set company_id = case when user_id = klebson_id then empadao_id when user_id = contato_id then brigadeiros_id else company_id end, created_by_user_id = coalesce(created_by_user_id, user_id) where company_id is null;
  update public.products set company_id = case when user_id = klebson_id then empadao_id when user_id = contato_id then brigadeiros_id else company_id end, created_by_user_id = coalesce(created_by_user_id, user_id) where company_id is null;
  update public.recipes set company_id = case when user_id = klebson_id then empadao_id when user_id = contato_id then brigadeiros_id else company_id end, created_by_user_id = coalesce(created_by_user_id, user_id) where company_id is null;
  update public.recipe_items set company_id = case when user_id = klebson_id then empadao_id when user_id = contato_id then brigadeiros_id else company_id end, created_by_user_id = coalesce(created_by_user_id, user_id) where company_id is null;
  update public.production_batches set company_id = case when user_id = klebson_id then empadao_id when user_id = contato_id then brigadeiros_id else company_id end, created_by_user_id = coalesce(created_by_user_id, user_id) where company_id is null;
  update public.inventory_movements set company_id = case when user_id = klebson_id then empadao_id when user_id = contato_id then brigadeiros_id else company_id end, created_by_user_id = coalesce(created_by_user_id, user_id) where company_id is null;
  update public.sales set company_id = case when user_id = klebson_id then empadao_id when user_id = contato_id then brigadeiros_id else company_id end, created_by_user_id = coalesce(created_by_user_id, user_id) where company_id is null;
  update public.sale_items set company_id = case when user_id = klebson_id then empadao_id when user_id = contato_id then brigadeiros_id else company_id end, created_by_user_id = coalesce(created_by_user_id, user_id) where company_id is null;
  update public.suppliers set company_id = case when user_id = klebson_id then empadao_id when user_id = contato_id then brigadeiros_id else company_id end, created_by_user_id = coalesce(created_by_user_id, user_id) where company_id is null;
  update public.purchase_batches set company_id = case when user_id = klebson_id then empadao_id when user_id = contato_id then brigadeiros_id else company_id end, created_by_user_id = coalesce(created_by_user_id, user_id) where company_id is null;
  update public.operating_expenses set company_id = case when user_id = klebson_id then empadao_id when user_id = contato_id then brigadeiros_id else company_id end, created_by_user_id = coalesce(created_by_user_id, user_id) where company_id is null;
end $$;

-- Nenhuma linha existente pode ficar sem contexto empresarial.
do $$
declare
  missing_count bigint;
begin
  select sum(missing) into missing_count from (
    select count(*) filter (where company_id is null) as missing from public.ingredients
    union all select count(*) filter (where company_id is null) from public.purchases
    union all select count(*) filter (where company_id is null) from public.products
    union all select count(*) filter (where company_id is null) from public.recipes
    union all select count(*) filter (where company_id is null) from public.recipe_items
    union all select count(*) filter (where company_id is null) from public.production_batches
    union all select count(*) filter (where company_id is null) from public.inventory_movements
    union all select count(*) filter (where company_id is null) from public.sales
    union all select count(*) filter (where company_id is null) from public.sale_items
    union all select count(*) filter (where company_id is null) from public.suppliers
    union all select count(*) filter (where company_id is null) from public.purchase_batches
    union all select count(*) filter (where company_id is null) from public.operating_expenses
  ) checks;
  if coalesce(missing_count, 0) > 0 then
    raise exception 'Migration stopped: % legacy rows have no company mapping', missing_count;
  end if;
end $$;

create or replace function public.current_user_company_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select cm.company_id
  from public.company_memberships cm
  where cm.user_id = auth.uid()
  order by cm.created_at asc
  limit 1
$$;

revoke all on function public.current_user_company_id() from public;
grant execute on function public.current_user_company_id() to authenticated;

alter table public.ingredients alter column company_id set default public.current_user_company_id();
alter table public.purchases alter column company_id set default public.current_user_company_id();
alter table public.products alter column company_id set default public.current_user_company_id();
alter table public.recipes alter column company_id set default public.current_user_company_id();
alter table public.recipe_items alter column company_id set default public.current_user_company_id();
alter table public.production_batches alter column company_id set default public.current_user_company_id();
alter table public.inventory_movements alter column company_id set default public.current_user_company_id();
alter table public.sales alter column company_id set default public.current_user_company_id();
alter table public.sale_items alter column company_id set default public.current_user_company_id();
alter table public.suppliers alter column company_id set default public.current_user_company_id();
alter table public.purchase_batches alter column company_id set default public.current_user_company_id();
alter table public.operating_expenses alter column company_id set default public.current_user_company_id();

alter table public.ingredients alter column company_id set not null;
alter table public.purchases alter column company_id set not null;
alter table public.products alter column company_id set not null;
alter table public.recipes alter column company_id set not null;
alter table public.recipe_items alter column company_id set not null;
alter table public.production_batches alter column company_id set not null;
alter table public.inventory_movements alter column company_id set not null;
alter table public.sales alter column company_id set not null;
alter table public.sale_items alter column company_id set not null;
alter table public.suppliers alter column company_id set not null;
alter table public.purchase_batches alter column company_id set not null;
alter table public.operating_expenses alter column company_id set not null;

create index if not exists ingredients_company_active_name_idx on public.ingredients(company_id, active, name);
create index if not exists products_company_active_name_idx on public.products(company_id, active, name);
create index if not exists purchases_company_date_idx on public.purchases(company_id, purchase_date desc);
create index if not exists sales_company_date_idx on public.sales(company_id, sale_date desc);

alter table public.companies enable row level security;
alter table public.company_domains enable row level security;
alter table public.company_memberships enable row level security;

drop policy if exists companies_member_read on public.companies;
drop policy if exists company_domains_member_read on public.company_domains;
drop policy if exists memberships_self_read on public.company_memberships;
create policy companies_member_read on public.companies for select to authenticated using (exists (select 1 from public.company_memberships cm where cm.company_id = companies.id and cm.user_id = auth.uid()));
create policy company_domains_member_read on public.company_domains for select to authenticated using (exists (select 1 from public.company_memberships cm where cm.company_id = company_domains.company_id and cm.user_id = auth.uid()));
create policy memberships_self_read on public.company_memberships for select to authenticated using (user_id = auth.uid());

-- Substitui o isolamento incorreto por utilizador pelo isolamento correto por empresa.
do $$
declare
  table_name text;
begin
  foreach table_name in array array['ingredients','purchases','products','recipes','recipe_items','production_batches','inventory_movements','sales','sale_items','suppliers','purchase_batches','operating_expenses'] loop
    execute format('drop policy if exists %I_user_access on public.%I', table_name, table_name);
    execute format('drop policy if exists %I_company_access on public.%I', table_name, table_name);
    execute format('create policy %I_company_access on public.%I for all to authenticated using (company_id = public.current_user_company_id()) with check (company_id = public.current_user_company_id())', table_name, table_name);
  end loop;
end $$;
