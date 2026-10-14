# Plataforma de pedidos de gás e água

Produto multi-tenant white-label para pedidos de gás e água, com operação por centrais, começando pelo piloto de Goiatuba. Empresas compartilharão a plataforma com isolamento rigoroso de dados. O repositório é privado e os projetos antigos do GitHub ficam fora do escopo.

## Estado atual

O modelo multi-tenant white-label foi aprovado, e há shells Flutter para cliente, proprietário e central, com as plataformas Android/iOS/Web iniciais. O pacote compartilhado `nucleo` agora inclui `Dinheiro`, que representa e formata valores em centavos inteiros sem ponto flutuante. O CI validou testes e compilou três APKs Android arm64 de depuração para prévia, além dos builds Web dos painéis; as dependências estão fixadas em `pubspec.lock`. As APKs individuais estão no [pré-lançamento privado do GitHub](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/releases/tag/previa-apks-android-arm64-38507526841); o artefato ZIP temporário expira em 21/10/2026 às 03:33:37 UTC. Os APKs dos painéis não resolvem D-006. Isso ainda não é produção: não há autenticação, backend ou dados de negócio conectados. Migrations e provisionamento dependem da revisão do modelo de acesso e das decisões pendentes.

## Documentação

- `CLAUDE.md`: regras de trabalho e qualidade.
- `docs/ARQUITETURA.md`: requisitos e arquitetura-base.
- `docs/DECISOES.md`: decisões registradas e pontos que precisam de aprovação.
- `docs/PROGRESSO.md`: estado do trabalho e próximo passo.
- `docs/IMPLEMENTACAO_E_HANDOFF.md`: guia técnico para revisão e continuidade pelo arquiteto sênior.
- `docs/MATRIZ_ACESSO_PROPOSTA.md`: proposta de permissões e testes de isolamento, aguardando aprovação.
- `apps/README.md`: apps, plataformas geradas e limites de produção.
- `docs/GUIA_APKS_PREVIA.md`: como baixar e instalar as três APKs de prévia.
- `docs/GUIA_BUILDS_TESTE.md`: documentação do build anterior de teste do app cliente e dos painéis Web.
- `supabase/README.md`: limites e preparação futura do backend, sem serviço provisionado.

## Princípios

Segurança e privacidade primeiro; Flutter/Dart para as interfaces; qualidade profissional, código organizado e decisões documentadas. As centrais são dados configuráveis, não cidades fixadas no código.
