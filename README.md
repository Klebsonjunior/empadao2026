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

Projeto Supabase: `kriartlove` (ref: `hfeotdvlrmxvlecybmyc`). O esquema base está em [`supabase/001_empadao_schema.sql`](supabase/001_empadao_schema.sql) e contém as tabelas `ingredients`, `purchases`, `products`, `recipes`, `recipe_items`, `production_batches`, `inventory_movements`, `sales`, `sale_items` e `suppliers`. O módulo financeiro usa [`002_finance_purchase_reports.sql`](supabase/002_finance_purchase_reports.sql), [`003_movement_dates.sql`](supabase/003_movement_dates.sql) e [`004_refresh_purchase_rpc.sql`](supabase/004_refresh_purchase_rpc.sql). Aplique os arquivos nessa ordem no SQL Editor para uma instalação nova. RLS ativo — somente o usuário autenticado acessa os próprios registros.

Uma compra é registrada como um lançamento de caixa com data, fornecedor, categoria, valor total, observação e referência da nota. Dentro dela, cada item possui quantidade, unidade e valor individual; o banco rejeita a operação quando a soma dos itens não corresponde ao total informado e atualiza o estoque e o custo médio em uma única transação. A aba **Relatórios** permite filtrar hoje, semana, mês ou datas personalizadas, além de separar Compras, Vendas, Produção, Ingredientes e Estoque ou mostrar o consolidado. O botão de impressão gera uma versão pronta para salvar ou anexar à prestação de contas.
