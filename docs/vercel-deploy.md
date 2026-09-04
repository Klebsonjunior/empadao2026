# Publicação na Vercel

## Configuração

O projeto é um frontend Vite estático. A configuração em `vercel.json` define `pnpm install --frozen-lockfile` como instalação, `pnpm run build` como build e `dist` como diretório de saída.

A Vercel deve receber estas variáveis de ambiente no ambiente de produção:

| Variável | Valor | Exposição |
|---|---|---|
| `VITE_SUPABASE_URL` | URL pública do projeto Supabase `hfeotdvlrmxvlecybmyc` | Pode ser incorporada no bundle |
| `VITE_SUPABASE_PUBLISHABLE_KEY` | Chave publishable/anon do projeto | Pode ser incorporada no bundle, protegida pelo RLS |

A chave `service_role` nunca deve ser configurada como `VITE_*` nem enviada ao browser. Operações administrativas futuras, como convites de utilizadores, deverão utilizar uma Edge Function ou backend protegido.

## Domínios

O hostname é usado pelo frontend para resolver a empresa atual através da tabela `company_domains`. O domínio não é uma barreira de segurança isolada: o Supabase confirma a associação do utilizador à empresa através de `company_memberships` e das políticas RLS.

Os primeiros domínios configurados no banco são `empadao2026.vercel.app` para Empadão e `brigadeirogourmet.vercel.app` para Brigadeiros. Cada novo domínio personalizado deve ser criado na Vercel e depois associado a uma empresa no Supabase antes de receber utilizadores.

## Validações executadas

O comando de instalação congelada e o build de produção foram executados localmente. O diretório `dist` foi gerado, o bundle foi servido com `vite preview`, a entrada, os assets e o fallback legado retornaram HTTP 200, e não foram encontrados nomes de chaves administrativas no código cliente.

O aviso atual do Vite sobre chunk JavaScript acima de 500 kB não impede a publicação. Antes de uma escala maior, recomenda-se separar os módulos por carregamento dinâmico para reduzir o primeiro carregamento.

## Publicação segura

A primeira publicação deve ser feita como preview na Vercel, com as variáveis públicas configuradas, para validar login, resolução do domínio e leitura por empresa. A substituição do site legado deve ocorrer apenas depois de testar Empadão com João e Silvana e Brigadeiros com o utilizador de teste.
