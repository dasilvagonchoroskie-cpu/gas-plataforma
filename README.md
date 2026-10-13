# Plataforma de pedidos de gás e água

Produto multi-tenant white-label para pedidos de gás e água, com operação por centrais, começando pelo piloto de Goiatuba. Empresas compartilharão a plataforma com isolamento rigoroso de dados. O repositório é privado e os projetos antigos do GitHub ficam fora do escopo.

## Estado atual

O modelo multi-tenant white-label foi aprovado, assim como APKs Android dedicados por empresa gerados da mesma base de código. Ainda não há código de produto, banco, ambientes ou integrações configurados. As decisões pendentes em `docs/DECISOES.md` precisam ser aprovadas antes das fases que dependem delas.

## Documentação

- `CLAUDE.md`: regras de trabalho e qualidade.
- `docs/ARQUITETURA.md`: requisitos e arquitetura-base.
- `docs/DECISOES.md`: decisões registradas e pontos que precisam de aprovação.
- `docs/PROGRESSO.md`: estado do trabalho e próximo passo.

## Princípios

Segurança e privacidade primeiro; Flutter/Dart para as interfaces; qualidade profissional, código organizado e decisões documentadas. As centrais são dados configuráveis, não cidades fixadas no código.
