# Progresso

**Atualizado:** 2026-10-14  
**Etapa:** Fase 0 — preparação do repositório concluída; Fase 1 ainda não começou.

## Objetivo

Uma revenda de gás e água atende Goiatuba, Itumbiara e Bom Jesus de Goiás. O piloto começa somente em Goiatuba. O produto terá um app Flutter para clientes e um painel web único para o dono e as centrais. A arquitetura completa está em `docs/ARQUITETURA.md`.

## Feito

- Registrada a arquitetura aprovada e as regras para continuar o projeto.
- Preparado `apps/painel` como estrutura única do painel; as pastas antigas foram mantidas como referência.
- Preparadas as pastas de funcionalidades do app cliente e do painel.
- Preparados os documentos de decisões, progresso e operação.
- CI do Flutter passou: dependências, formatação, análise estática e testes. [Execução de validação](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/actions/runs/38513731244).
- Lockfile do painel unificado registrado com sucesso. [Execução de lockfiles](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/actions/runs/38513731202).
- Evandro informou que vinculou o Supabase ao GitHub; o projeto e as opções da integração ainda precisam ser confirmados.

## Falta

- Confirmar que a integração do Supabase aponta somente para o ambiente gratuito de desenvolvimento e que nenhuma implantação em produção está habilitada.
- Se o projeto gratuito de desenvolvimento ainda não existir, criá-lo em organização separada.
- Depois da confirmação e de autorização de Evandro, iniciar a Fase 1 conforme `docs/ARQUITETURA.md`.

## Limites respeitados

Não há ambiente de produção criado ou acessado. Nenhuma migration, função de negócio ou seed com dados de negócio foi criada; a Fase 1 não começou.

## Próximo passo

Claude Code deve ler `CLAUDE.md`, `docs/ARQUITETURA.md` e `docs/IMPLEMENTACAO_E_HANDOFF.md`, confirmar a integração informada e continuar somente após a autorização de Evandro.
