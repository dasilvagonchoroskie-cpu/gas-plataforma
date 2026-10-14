# Plataforma de pedidos de gás e água

Plataforma para uma única revenda de gás e água, com centrais em Goiatuba, Itumbiara e Bom Jesus de Goiás. O piloto ativa somente a central de Goiatuba. O escopo e as decisões aprovadas estão em [`docs/ARQUITETURA.md`](docs/ARQUITETURA.md).

## Estado da Fase 0

A arquitetura versão 1 foi registrada. O projeto prepara um app Flutter do cliente, um painel Flutter Web unificado para dono e central e o pacote compartilhado `packages/nucleo`. Há CI no GitHub Actions. O projeto Supabase de desenvolvimento ainda será criado pelo dono; não existe produção, nenhum banco foi conectado e nenhuma migration foi criada.

Há shells de interface de uma preparação anterior; eles não substituem a arquitetura versão 1. Os APKs de prévia dessa etapa anterior são somente artefatos técnicos privados e não fazem parte da distribuição de produção. Novas implementações devem seguir a ordem das fases da arquitetura e não antecipar funções fora do escopo.

## Documentos principais

- [`CLAUDE.md`](CLAUDE.md): regras da seção 1 da arquitetura e fluxo de aprovação.
- [`docs/ARQUITETURA.md`](docs/ARQUITETURA.md): escopo, stack, segurança, dados, estrutura e ordem das fases.
- [`docs/DECISOES.md`](docs/DECISOES.md): resumo das decisões fechadas e estado dos ambientes.
- [`docs/PROGRESSO.md`](docs/PROGRESSO.md): o que foi feito, o que falta e o próximo passo.
- [`docs/RUNBOOK.md`](docs/RUNBOOK.md): preparação de backup, restauração, troca de chaves e contingência.
- [`apps/README.md`](apps/README.md): estrutura do app cliente e painel unificado.
