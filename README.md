# Controle Empadões

Sistema de controle de custo, estoque e vendas. Site estático (1 arquivo HTML), sem build, conectado a um banco Supabase real.

## Deploy

1. Crie um repositório no GitHub e suba este `index.html` (e este README) nele.
2. No Vercel: **New Project → Import Git Repository** → selecione o repositório.
3. Framework preset: **Other** (não precisa de build command, nem output directory — é HTML estático).
4. Deploy.

Pronto. A URL do Vercel já funciona — não precisa de variável de ambiente, porque a chave usada no código (`sb_publishable_...`) é pública por natureza (protegida pelas políticas RLS no banco, não por sigilo).

## Primeiro acesso

Abra a URL, clique em "Criar conta", cadastre seu e-mail e senha. Se o Supabase pedir confirmação por e-mail, confirme antes de logar (isso é padrão de segurança do Supabase, pode desativar em Authentication → Settings se quiser pular essa etapa).

## Banco de dados

Projeto Supabase: `kriartlove` (ref: `hfeotdvlrmxvlecybmyc`). O esquema está versionado em [`supabase/001_empadao_schema.sql`](supabase/001_empadao_schema.sql) e contém as tabelas `ingredients`, `purchases`, `products`, `recipes`, `recipe_items`, `production_batches`, `inventory_movements`, `sales`, `sale_items` e `suppliers`. RLS ativo — somente o usuário autenticado acessa os próprios registros.

A migração `empadao_schema` já foi aplicada ao projeto configurado. Em uma nova instalação, aplique esse arquivo no SQL Editor do projeto antes do primeiro acesso. O aplicativo também valida cada resposta do Supabase e só exibe mensagens de sucesso depois que a persistência e o recarregamento dos dados são confirmados.
