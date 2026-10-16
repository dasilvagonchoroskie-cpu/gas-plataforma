# Backend Supabase

O Supabase é o backend aprovado para esta plataforma: um único projeto por ambiente, usando Postgres, Auth, Realtime, Storage e Edge Functions. Não serão usados microsserviços. O Firebase Cloud Messaging fica restrito ao envio de notificações push.

**Estado:** projeto de desenvolvimento `cytxdxnansmzptzhnrfq` (conta da plataforma, plano gratuito). Produção ainda não existe; será criada na fase prevista na arquitetura, com aprovação.

- `migrations/` — mudanças versionadas do banco (ver o README da pasta).
- `tests/` — testes pgTAP de regras e permissões.
- `seed.sql` — dados fictícios só para desenvolvimento.
- `functions/` — Edge Functions: `cadastro`, `admin-usuarios`, `excluir-conta`, `endereco`, `notificar`, `assinatura-android`.

Segredos do servidor ficam no Vault (`notificar_url`, `notificar_segredo`, `android_chave_*`) e são lidos só pelas Edge Functions (função `segredo_do_servidor`, restrita à `service_role`). O único segredo de Edge Function que falta cadastrar é `FCM_CONTA_SERVICO` (Firebase, para notificações).

## Regras obrigatórias

- Todas as tabelas terão RLS habilitada; sem política explícita, não há acesso.
- As permissões do banco são a autoridade. Filtros na interface não substituem RLS.
- `service_role` nunca pode ser incluída em apps ou no repositório; somente a chave pública `anon` pode ser usada na configuração do app.
- Migrations versionadas serão o único caminho para mudanças no banco; nenhuma alteração manual direta em produção.
- Testes usarão contas e dados sintéticos de desenvolvimento, sem segredos ou dados pessoais reais.
- Valores monetários são inteiros em centavos, e datas no banco ficam em UTC.

## Etapas

Fase 1 (banco, RLS, RPC, seed e testes) concluída no desenvolvimento, com os testes passando. Detalhes e pendências em `docs/PROGRESSO.md`.
