# Plano técnico de migração multiempresa

## Decisão de arquitetura

O mesmo projeto Supabase (`hfeotdvlrmxvlecybmyc`) será utilizado por vários clientes. Cada cliente terá uma empresa (`companies`) e um ou mais domínios (`company_domains`). Cada conta autenticada terá uma associação explícita a uma empresa (`company_memberships`). O domínio será usado para resolver a empresa no frontend, mas a segurança será garantida pelo RLS através da associação do utilizador.

## Mapeamento inicial confirmado

| Domínio | Empresa | Utilizador inicial | Registos existentes |
|---|---|---|---|
| `empadao2026.vercel.app` | Empadão | `klebson-junior@hotmail.com` e `sil.balena21@gmail.com` | Dados atualmente atribuídos ao utilizador Klebson |
| `brigadeirogourmet.vercel.app` | Brigadeiros | `contato.jejr@gmail.com` | Dados de teste de compras, vendas, produção, produtos e ingredientes |

## Dados legados

As tabelas de gestão existentes têm `user_id` e RLS por utilizador. A migration adicionará `company_id`, manterá `user_id` como autor técnico legado e criará `created_by_user_id` para auditoria futura. Os registos de cada utilizador conhecido serão atribuídos à empresa correspondente sem alterar valores, chaves ou relações entre linhas.

A tabela `pedidos_ensaio` fica fora desta migração porque pertence a outro fluxo de pedidos e possui políticas públicas próprias. Ela não será tornada acessível por associação empresarial sem análise separada.

## Segurança

As novas políticas serão aplicadas apenas às tabelas de gestão. Uma função `current_user_company_id()` obtém a empresa do utilizador autenticado a partir de `company_memberships`. As políticas permitirão acesso somente quando `company_id` for a empresa do utilizador atual. A autenticação continuará individual; não haverá conta partilhada.

O domínio não será a única defesa. O RLS continuará ativo e impedirá que um utilizador associado ao Empadão leia ou escreva dados do Brigadeiros, mesmo que tente alterar o hostname ou os parâmetros de uma chamada.

## Fases de execução

Primeiro será criado um backup lógico e validada a contagem por utilizador. Depois a migration será aplicada de forma transacional, com tabelas, associações, preenchimento de `company_id`, defaults e novas políticas. Só depois o frontend React/Vite será ligado ao novo contexto empresarial. A última etapa será validar a partilha João–Silvana no Empadão e o isolamento Empadão–Brigadeiros.

## Gestão futura de utilizadores

O cadastro autenticado continuará a criar a conta individual. Para adicionar utilizadores a uma empresa, o caminho seguro será um convite ou uma Edge Function administrativa que use credencial de servidor apenas no backend; a chave `service_role` nunca será incluída no frontend. O nível inicial será `administrator` ou `user`.
