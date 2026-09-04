-- Migration 008: endurecer a função de contexto empresarial.
-- A política de leitura de company_memberships já permite ao utilizador ler a sua própria associação,
-- portanto a função não precisa de SECURITY DEFINER.

create or replace function public.current_user_company_id()
returns uuid
language sql
stable
security invoker
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
