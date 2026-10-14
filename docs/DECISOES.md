# Decisões do projeto

Este resumo acompanha `docs/ARQUITETURA.md`, que é a fonte principal e aprovada. Se houver diferença, prevalece a arquitetura mais recente aprovada por Evandro.

## Decisões fechadas

- Um único vendedor atende Goiatuba, Itumbiara e Bom Jesus de Goiás; no piloto, somente a central de Goiatuba fica ativa.
- O dono controla todas as centrais; centrais são registros do banco e não ficam fixadas no código.
- Flutter para o app do cliente Android/iOS e Flutter Web para o painel único de dono e central.
- App cliente usa Riverpod, go_router e supabase_flutter; modelos e regras compartilhados ficam em `packages/nucleo`.
- Um backend Supabase (Postgres, Auth, Realtime, Storage e Edge Functions), sem microsserviços. Firebase Cloud Messaging é usado somente para push.
- Dados e permissões são protegidos por RLS no banco; a chave `service_role` nunca vai para apps.
- Valores monetários são inteiros em centavos; datas no banco são UTC e apresentadas em `America/Sao_Paulo`.
- Migrations são versionadas; produção nunca é alterada manualmente.
- A assinatura fica para a etapa final com Claude Code, sem certificados/chaves no repositório.
- Seguir estritamente a ordem e o escopo de `docs/ARQUITETURA.md`.

## Estado dos ambientes

- Evandro tem uma conta GitHub.
- O projeto Supabase de desenvolvimento gratuito ainda será criado por Evandro, em organização separada.
- O ambiente de produção não existe e fica fora desta Fase 0; nenhuma conta, projeto ou banco de produção será criado ou acessado agora.
- Nenhuma migration, seed com dados de negócio ou credencial de Supabase foi criada nesta etapa.

## Registro

- 2026-10-14 — Arquitetura versão 1 recebida e adotada como fonte principal do projeto; estrutura e trabalho devem seguir suas fases e limites.
- 2026-10-14 — Fase 0 autorizada sem ambiente de produção; verificação do computador local depende de execução guiada por Evandro ou Claude Code, pois esta sessão não tem acesso ao computador físico.
