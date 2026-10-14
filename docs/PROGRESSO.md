# Progresso

**Atualizado:** 2026-10-14  
**Etapa atual:** Fase 0 — preparação do repositório concluída; conferência local e ambiente de desenvolvimento ainda pendentes.

## Feito

- Registrada em `docs/ARQUITETURA.md` a arquitetura aprovada versão 1 (13/10/2026), fonte de verdade para escopo, decisões e ordem das fases.
- Alinhados `CLAUDE.md`, `docs/DECISOES.md`, README do repositório, `apps/README.md` e a documentação de Supabase à arquitetura aprovada.
- Preparado `apps/painel/` como esqueleto seguro do painel web unificado de dono e central. Os shells antigos foram mantidos temporariamente como referência. O novo painel não tem login, backend nem dados comerciais simulados.
- Preparadas pastas por funcionalidade para o app cliente e painel unificado.
- Atualizados os READMEs do backend; `supabase/seed.sql` contém apenas comentários. Não foram criadas migrations, funções, dados de negócio ou credenciais.
- Criado esqueleto inicial de `docs/RUNBOOK.md`, ainda sem procedimentos operacionais testados.
- O GitHub Actions [Verificações Flutter, execução 38513731244](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/actions/runs/38513731244) concluiu com sucesso no commit `745f1dc375e646f8c8399b8cb7c880f9bf256680`: resolução de dependências, formatação, análise estática e testes de todos os pacotes Flutter, incluindo o painel unificado.
- O workflow [Fixar dependências Flutter, execução 38513731202](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/actions/runs/38513731202) também concluiu com sucesso, validou os pacotes e registrou `apps/painel/pubspec.lock` no commit `31ce2209d4aafc5ae1f11642e7a1ae97e2176cdf`.

## Ainda falta

- Claude Code deve conferir o repositório no computador de Evandro e verificar/instalar o ambiente local. Esta execução não tem `flutter`, `dart`, `git` nem CLI do Supabase; isso descreve somente este ambiente, e o computador de Evandro não foi verificado.
- Evandro ainda criará o projeto Supabase gratuito de desenvolvimento numa organização separada. Não compartilhar chaves pelo chat nem registrá-las no repositório.
- O runbook precisa ser completado e testado antes do piloto.

## Limites respeitados

Nenhum projeto Supabase foi criado ou conectado; nenhum banco de produção foi criado, acessado ou alterado. Nenhuma migration, seed de negócio ou atividade da Fase 1 foi iniciada. A produção permanece intocada.

## Próximo passo

Fazer a conferência local e preparar o projeto Supabase gratuito de desenvolvimento com Claude Code, mantendo esta tarefa na Fase 0. Parar aqui: iniciar a Fase 1 somente depois de autorização explícita de Evandro. Não criar nem acessar produção.
