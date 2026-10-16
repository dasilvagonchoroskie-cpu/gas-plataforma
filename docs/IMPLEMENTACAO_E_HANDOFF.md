# Continuidade do projeto — Claude Code

Ponto de retomada. **A fonte principal é `docs/ARQUITETURA.md` (versão 2); leia-a inteira antes de implementar.** O estado detalhado e a lista do que falta estão em `docs/PROGRESSO.md`; as decisões em `docs/DECISOES.md`; a operação em `docs/RUNBOOK.md`.

## Mapa rápido

- `supabase/migrations/` — banco (aplicar em ordem; números iguais aos do servidor).
- `supabase/tests/` — testes pgTAP; rodar com `scripts/testar_banco_local.sh` ou pela esteira.
- `supabase/functions/` — Edge Functions (Deno, imports `npm:`).
- `packages/nucleo`, `packages/design_system`, `packages/dados` — código compartilhado.
- `apps/cliente` — app do cliente (go_router).
- `apps/painel` — painel do dono e da central (escolhe a interface pelo papel do perfil).
- `scripts/ci/validar_flutter.sh` e `.github/workflows/` — esteira.

## Como validar

- Não há Flutter nesta máquina de trabalho; a validação Flutter roda no GitHub Actions. O resultado fica no ramo `ci-relatorio` (`git fetch origin ci-relatorio` e ler `relatorio.txt`).
- O banco pode ser testado localmente com Postgres + pgTAP (`scripts/testar_banco_local.sh`) e no Supabase completo pela esteira (`ci-relatorio-banco`).

## Regras que não podem ser esquecidas

- Seguir a ordem da seção 11 da arquitetura; não inventar escopo.
- Nunca pedir nem registrar senhas ou `service_role`; nenhuma chave secreta vai para código ou repositório.
- Nunca alterar produção manualmente. Mudanças de banco são migrations versionadas e testadas.
- Evandro é iniciante: explicar cada passo em português simples.
