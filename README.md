# Plataforma de pedidos de gás e água

Produto multi-tenant white-label para pedidos de gás e água, com operação por centrais, começando pelo piloto de Goiatuba. Empresas compartilharão a plataforma com isolamento rigoroso de dados. O repositório é privado e os projetos antigos do GitHub ficam fora do escopo.

## Estado atual

O modelo multi-tenant white-label foi aprovado, e há shells Flutter para cliente, proprietário e central, com as plataformas Android/iOS/Web iniciais. O CI validou os testes, gerou um APK Android de depuração e builds Web de teste; as dependências estão fixadas em `pubspec.lock`. Isso ainda não é uma plataforma de produção: não há autenticação, backend ou dados de negócio conectados. Migrations e provisionamento dependem da revisão do modelo de acesso e das decisões pendentes.

## Documentação

- `CLAUDE.md`: regras de trabalho e qualidade.
- `docs/ARQUITETURA.md`: requisitos e arquitetura-base.
- `docs/DECISOES.md`: decisões registradas e pontos que precisam de aprovação.
- `docs/PROGRESSO.md`: estado do trabalho e próximo passo.
- `docs/IMPLEMENTACAO_E_HANDOFF.md`: guia técnico para revisão e continuidade pelo arquiteto sênior.
- `docs/MATRIZ_ACESSO_PROPOSTA.md`: proposta de permissões e testes de isolamento, aguardando aprovação.
- `apps/README.md`: apps, plataformas geradas e limites de produção.
- `docs/GUIA_BUILDS_TESTE.md`: como obter e interpretar o APK e os builds Web de teste.
- `supabase/README.md`: limites e preparação futura do backend, sem serviço provisionado.

## Princípios

Segurança e privacidade primeiro; Flutter/Dart para as interfaces; qualidade profissional, código organizado e decisões documentadas. As centrais são dados configuráveis, não cidades fixadas no código.
