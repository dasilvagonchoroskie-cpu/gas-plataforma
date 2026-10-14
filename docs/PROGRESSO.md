# Progresso

**Atualizado:** 2026-10-14  
**Etapa atual:** Fase 0 — preparação do repositório; ainda não concluída.

## Feito nesta preparação

- Registrada em `docs/ARQUITETURA.md` a arquitetura aprovada versão 1 (13/10/2026), que é a fonte de verdade para escopo, decisões e ordem das fases.
- Atualizados `CLAUDE.md`, `docs/DECISOES.md`, README do repositório e `apps/README.md` para seguirem a arquitetura: um app do cliente, um painel web unificado, backend Supabase único, sem microsserviços, e proibição de antecipar fases.
- Preparado `apps/painel/` como esqueleto seguro do painel unificado, preservando temporariamente os shells antigos como referência. O novo painel não tem login, conexão com backend nem dados comerciais simulados.
- Atualizados os READMEs de Supabase para refletir as decisões aprovadas; `supabase/seed.sql` contém somente comentários. Não foram criadas migrations, funções ou dados de negócio.
- Criado um esqueleto inicial de `docs/RUNBOOK.md`, ainda sem procedimentos de operação testados.

## Limites e validação

- Nenhum projeto Supabase foi conectado ou criado nesta execução. O projeto gratuito de desenvolvimento ainda será criado por Evandro, em organização separada.
- Nenhum projeto ou banco de produção foi criado, acessado ou alterado. Nenhuma migration ou mudança de Fase 1 foi iniciada.
- A execução atual não tem `flutter`, `dart`, `git` nem CLI do Supabase disponíveis. Isso descreve somente este ambiente de execução; o computador de Evandro não foi verificado.
- Os testes Flutter e a análise estática do novo pacote ainda dependem do GitHub Actions. A validação CI desta versão está pendente; não declarar o painel nem a Fase 0 concluídos antes de verificar os resultados.

## Falta para concluir a Fase 0

- Validar o painel unificado e os demais pacotes no workflow de CI e resolver eventuais falhas.
- Confirmar o registro do `pubspec.lock` do novo painel pelo workflow de dependências.
- Fazer a conferência local do repositório com Claude Code ou com orientação ao desenvolvedor, pois esta execução não acessa o computador de Evandro.
- Evandro criar o projeto Supabase gratuito de desenvolvimento em organização separada; não compartilhar chaves no chat nem registrá-las no repositório.

## Próximo passo

Concluir a validação de CI da Fase 0, conferir o estado local com Claude Code e registrar os resultados aqui. Parar ao fim da Fase 0 e pedir autorização explícita antes de iniciar a Fase 1. Não criar nem acessar produção.
