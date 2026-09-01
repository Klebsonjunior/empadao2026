-- Esquema do Controle Empadões.
-- Aplicar no projeto Supabase usado pelo index.html.

create table if not exists public.ingredients (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null check (char_length(trim(name)) > 0),
  family text not null check (family in ('peso', 'volume', 'unidade')),
  unit text not null check (unit in ('kg', 'g', 'l', 'ml', 'un')),
  stock numeric not null default 0 check (stock >= 0),
  avg_cost numeric not null default 0 check (avg_cost >= 0),
  min_stock numeric not null default 0 check (min_stock >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  ingredient_id uuid not null references public.ingredients(id) on delete restrict,
  purchase_date date not null,
  qty numeric not null check (qty > 0),
  unit text not null check (unit in ('kg', 'g', 'l', 'ml', 'un')),
  qty_base numeric not null check (qty_base > 0),
  total_cost numeric not null check (total_cost >= 0),
  cost_per_base numeric not null check (cost_per_base >= 0),
  avg_cost_before numeric not null default 0 check (avg_cost_before >= 0),
  avg_cost_after numeric not null default 0 check (avg_cost_after >= 0),
  created_at timestamptz not null default now()
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null check (char_length(trim(name)) > 0),
  price numeric not null default 0 check (price >= 0),
  stock numeric not null default 0 check (stock >= 0),
  min_stock numeric not null default 0 check (min_stock >= 0),
  last_unit_cost numeric not null default 0 check (last_unit_cost >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.recipes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  product_id uuid not null unique references public.products(id) on delete cascade,
  yield_qty numeric not null check (yield_qty > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.recipe_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  recipe_id uuid not null references public.recipes(id) on delete cascade,
  ingredient_id uuid not null references public.ingredients(id) on delete restrict,
  qty numeric not null check (qty > 0),
  unit text not null check (unit in ('kg', 'g', 'l', 'ml', 'un')),
  created_at timestamptz not null default now()
);

create table if not exists public.production_batches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  production_date date not null,
  qty_planned numeric not null check (qty_planned > 0),
  qty_produced numeric not null check (qty_produced >= 0),
  qty_lost numeric not null default 0 check (qty_lost >= 0),
  usable_qty numeric not null default 0 check (usable_qty >= 0),
  batch_cost numeric not null default 0 check (batch_cost >= 0),
  unit_cost numeric not null default 0 check (unit_cost >= 0),
  forced boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  item_type text not null check (item_type in ('ingredient', 'product')),
  item_id uuid not null,
  movement_type text not null check (movement_type in ('compra', 'producao_saida', 'producao_entrada', 'venda', 'cancelamento')),
  qty_before numeric not null default 0,
  qty_change numeric not null default 0,
  qty_after numeric not null default 0,
  note text,
  origin_id uuid,
  created_at timestamptz not null default now()
);

create table if not exists public.sales (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  sale_date date not null,
  discount numeric not null default 0 check (discount >= 0),
  total numeric not null default 0 check (total >= 0),
  cost numeric not null default 0 check (cost >= 0),
  profit numeric not null default 0,
  cancelled boolean not null default false,
  cancelled_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.sale_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  sale_id uuid not null references public.sales(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  qty numeric not null check (qty > 0),
  unit_price numeric not null check (unit_price >= 0),
  cost_unit numeric not null default 0 check (cost_unit >= 0),
  subtotal numeric not null default 0 check (subtotal >= 0),
  cost_line numeric not null default 0 check (cost_line >= 0),
  created_at timestamptz not null default now()
);

create table if not exists public.suppliers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null check (char_length(trim(name)) > 0),
  contact text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists ingredients_user_active_name_idx on public.ingredients (user_id, active, name);
create index if not exists products_user_active_name_idx on public.products (user_id, active, name);
create index if not exists purchases_user_date_idx on public.purchases (user_id, purchase_date desc);
create index if not exists recipe_items_recipe_idx on public.recipe_items (recipe_id);
create index if not exists production_batches_user_date_idx on public.production_batches (user_id, production_date desc);
create index if not exists inventory_movements_user_created_idx on public.inventory_movements (user_id, created_at desc);
create index if not exists sales_user_date_idx on public.sales (user_id, sale_date desc);
create index if not exists sale_items_sale_idx on public.sale_items (sale_id);

alter table public.ingredients enable row level security;
alter table public.purchases enable row level security;
alter table public.products enable row level security;
alter table public.recipes enable row level security;
alter table public.recipe_items enable row level security;
alter table public.production_batches enable row level security;
alter table public.inventory_movements enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.suppliers enable row level security;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'ingredients', 'purchases', 'products', 'recipes', 'recipe_items',
    'production_batches', 'inventory_movements', 'sales', 'sale_items', 'suppliers'
  ] loop
    execute format('drop policy if exists %I_user_access on public.%I', table_name, table_name);
    execute format(
      'create policy %I_user_access on public.%I for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid())',
      table_name, table_name
    );
  end loop;
end $$;
