-- Compras por embalagem: preserva o que veio na nota e converte para a unidade de estoque.
alter table public.purchases add column if not exists purchase_qty numeric;
alter table public.purchases add column if not exists purchase_unit text;
alter table public.purchases add column if not exists content_qty numeric;
alter table public.purchases add column if not exists content_unit text;

update public.purchases
set purchase_qty = qty,
    purchase_unit = unit,
    content_qty = 1,
    content_unit = unit
where purchase_qty is null;

create or replace function public.register_purchase_batch(
  p_purchase_date date,
  p_purchase_category text,
  p_supplier_name text,
  p_total_cost numeric,
  p_items jsonb,
  p_note text default null,
  p_receipt_reference text default null
)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_batch_id uuid;
  v_item jsonb;
  v_item_total numeric;
  v_sum_total numeric;
  v_purchase_qty numeric;
  v_purchase_unit text;
  v_content_qty numeric;
  v_content_unit text;
  v_qty numeric;
  v_qty_base numeric;
  v_ingredient_id uuid;
  v_old_stock numeric;
  v_old_avg numeric;
  v_new_stock numeric;
  v_new_avg numeric;
  v_ingredient public.ingredients%rowtype;
begin
  if v_user_id is null then raise exception 'Usuário não autenticado.' using errcode = '42501'; end if;
  if p_purchase_date is null then raise exception 'A data da compra é obrigatória.'; end if;
  if p_purchase_category not in ('mercado', 'casa_embalagens', 'outro') then raise exception 'Categoria de compra inválida.'; end if;
  if nullif(trim(coalesce(p_supplier_name, '')), '') is null then raise exception 'O mercado ou fornecedor é obrigatório.'; end if;
  if p_total_cost is null or p_total_cost < 0 then raise exception 'O valor total da compra é inválido.'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'A compra precisa ter pelo menos um item.'; end if;

  select round(coalesce(sum((item->>'total_cost')::numeric), 0), 2) into v_sum_total from jsonb_array_elements(p_items) as item;
  if v_sum_total <> round(p_total_cost, 2) then raise exception 'O total da compra deve ser igual à soma dos itens. Soma: R$ %, informado: R$ %.', v_sum_total, round(p_total_cost, 2); end if;

  insert into public.purchase_batches (user_id, purchase_date, purchase_category, supplier_name, total_cost, note, receipt_reference)
  values (v_user_id, p_purchase_date, p_purchase_category, trim(p_supplier_name), round(p_total_cost, 2), p_note, p_receipt_reference)
  returning id into v_batch_id;

  for v_item in select value from jsonb_array_elements(p_items) as value loop
    v_ingredient_id := (v_item->>'ingredient_id')::uuid;
    v_purchase_qty := coalesce((v_item->>'purchase_qty')::numeric, (v_item->>'qty')::numeric);
    v_purchase_unit := coalesce(v_item->>'purchase_unit', v_item->>'unit');
    v_content_qty := coalesce((v_item->>'content_qty')::numeric, 1);
    v_content_unit := coalesce(v_item->>'content_unit', v_item->>'unit');
    v_qty := v_purchase_qty * v_content_qty;
    v_item_total := round((v_item->>'total_cost')::numeric, 2);

    if v_purchase_qty is null or v_purchase_qty <= 0 or v_content_qty is null or v_content_qty <= 0 or v_item_total is null or v_item_total < 0 then raise exception 'Quantidade, conteúdo e valor de cada item devem ser válidos.'; end if;
    if v_content_unit not in ('kg', 'g', 'l', 'ml', 'un') then raise exception 'Unidade do conteúdo inválida.'; end if;

    select * into v_ingredient from public.ingredients where id = v_ingredient_id and user_id = v_user_id and active = true for update;
    if not found then raise exception 'Ingrediente não encontrado ou sem permissão.' using errcode = '42501'; end if;
    if (v_ingredient.family = 'peso' and v_content_unit not in ('kg', 'g')) or (v_ingredient.family = 'volume' and v_content_unit not in ('l', 'ml')) or (v_ingredient.family = 'unidade' and v_content_unit <> 'un') then raise exception 'A unidade do item não pertence à mesma família do ingrediente %.', v_ingredient.name; end if;

    v_qty_base := v_qty * case v_content_unit when 'kg' then 1000 when 'g' then 1 when 'l' then 1000 when 'ml' then 1 else 1 end;
    v_old_stock := coalesce(v_ingredient.stock, 0);
    v_old_avg := coalesce(v_ingredient.avg_cost, 0);
    v_new_stock := v_old_stock + v_qty_base;
    v_new_avg := case when v_new_stock > 0 then ((v_old_stock * v_old_avg) + v_item_total) / v_new_stock else 0 end;

    insert into public.purchases (user_id, purchase_batch_id, ingredient_id, purchase_date, qty, unit, qty_base, total_cost, cost_per_base, avg_cost_before, avg_cost_after, purchase_qty, purchase_unit, content_qty, content_unit)
    values (v_user_id, v_batch_id, v_ingredient_id, p_purchase_date, v_qty, v_content_unit, v_qty_base, v_item_total, v_item_total / v_qty_base, v_old_avg, v_new_avg, v_purchase_qty, v_purchase_unit, v_content_qty, v_content_unit);

    update public.ingredients set stock = v_new_stock, avg_cost = v_new_avg, updated_at = now() where id = v_ingredient_id and user_id = v_user_id;
    insert into public.inventory_movements (user_id, item_type, item_id, movement_type, movement_date, qty_before, qty_change, qty_after, note, origin_id)
    values (v_user_id, 'ingredient', v_ingredient_id, 'compra', p_purchase_date, v_old_stock, v_qty_base, v_new_stock, 'Compra em ' || p_purchase_date || ' - ' || trim(p_supplier_name), v_batch_id);
  end loop;
  return v_batch_id;
end;
$$;

revoke all on function public.register_purchase_batch(date, text, text, numeric, jsonb, text, text) from public;
grant execute on function public.register_purchase_batch(date, text, text, numeric, jsonb, text, text) to authenticated;
