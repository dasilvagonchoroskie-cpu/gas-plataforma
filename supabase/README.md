# Backend Supabase

O Supabase é o backend aprovado para esta plataforma: um único projeto por ambiente, usando Postgres, Auth, Realtime, Storage e Edge Functions. Não serão usados microsserviços. O Firebase Cloud Messaging fica restrito ao envio de notificações push.

**Estado:** Evandro informou que vinculou o Supabase ao GitHub. Ainda falta confirmar qual projeto está conectado e revisar as opções de implantação. Usar somente o projeto gratuito de desenvolvimento em organização separada; produção não existe e não será criada nem acessada nesta etapa.

## Regras obrigatórias

- Todas as tabelas terão RLS habilitada; sem política explícita, não há acesso.
- As permissões do banco são a autoridade. Filtros na interface não substituem RLS.
- `service_role` nunca pode ser incluída em apps ou no repositório; somente a chave pública `anon` pode ser usada na configuração do app.
- Migrations versionadas serão o único caminho para mudanças no banco; nenhuma alteração manual direta em produção.
- Testes usarão contas e dados sintéticos de desenvolvimento, sem segredos ou dados pessoais reais.
- Valores monetários são inteiros em centavos, e datas no banco ficam em UTC.

## Etapas

Migrations, RLS, RPC, seed com dados de teste e testes de isolamento pertencem à Fase 1 e não devem ser antecipados. Antes dela, confirmar com Evandro que a integração aponta somente para o projeto gratuito de desenvolvimento e aguardar autorização explícita.
