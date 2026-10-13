# Progresso

**Atualizado:** 2026-10-13

## Feito

- Criado o repositório privado `gas-plataforma` na conta GitHub `dasilvagonchoroskie-cpu`.
- Registradas as regras do trabalho em `CLAUDE.md`.
- Criadas a arquitetura-base e a lista de decisões em aberto.
- Aprovado o modelo multi-tenant white-label: várias empresas na plataforma compartilhada, com isolamento obrigatório por empresa.
- Definidos APKs Android dedicados por empresa, gerados da mesma base de código por variantes/Flavors e distribuídos diretamente.
- Nenhum repositório antigo foi acessado ou alterado.
- Nenhum código do aplicativo, migration, ambiente Supabase ou integração de pagamento foi criado.

## Falta

- Fechar as regras de proximidade, transferência entre centrais, preço, reserva de estoque/horário e Pix.
- Definir o caminho de distribuição do iOS, já que APKs dedicados foram aprovados apenas para Android.
- Definir assinatura, identificador do aplicativo por empresa, hospedagem e atualizações dos APKs diretos.
- Detalhar e aprovar o modelo de empresas, vínculos de usuários, políticas RLS e testes de isolamento antes da primeira migration.
- Definir se o painel do proprietário será apenas web responsivo ou também app móvel.

## Próximo passo

Revisar com Evandro as decisões pendentes D-002 a D-008 de `docs/DECISOES.md` antes de iniciar código ou migrations.
