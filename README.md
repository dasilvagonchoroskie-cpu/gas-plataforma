# Plataforma de pedidos de gás e água

Produto multi-tenant white-label para pedidos de gás e água, com operação por centrais, começando pelo piloto de Goiatuba. Empresas compartilharão a plataforma com isolamento rigoroso de dados. O repositório é privado e os projetos antigos do GitHub ficam fora do escopo.

## Estado atual

O modelo multi-tenant white-label foi aprovado, assim como APKs Android dedicados por empresa gerados da mesma base de código. Já existe um pacote Dart inicial de configuração pública de marca e o CI executa análise/testes. Os apps completos e qualquer projeto de banco/serviço em nuvem ainda não foram criados ou conectados. A proposta de handoff e as decisões pendentes estão documentadas; migrations dependem da aprovação do modelo de acesso.

## Documentação

- `CLAUDE.md`: regras de trabalho e qualidade.
- `docs/ARQUITETURA.md`: requisitos e arquitetura-base.
- `docs/DECISOES.md`: decisões registradas e pontos que precisam de aprovação.
- `docs/PROGRESSO.md`: estado do trabalho e próximo passo.
- `docs/IMPLEMENTACAO_E_HANDOFF.md`: guia técnico para revisão e continuidade pelo arquiteto sênior.
- `docs/MATRIZ_ACESSO_PROPOSTA.md`: proposta de permissões e testes de isolamento, aguardando aprovação.
- `apps/README.md` e `supabase/README.md`: estrutura proposta e limites das futuras integrações.

## Princípios

Segurança e privacidade primeiro; Flutter/Dart para as interfaces; qualidade profissional, código organizado e decisões documentadas. As centrais são dados configuráveis, não cidades fixadas no código.
