# Plataforma de pedidos de gás e água

Plataforma de uma única revenda de gás e água mineral. O dono abre quantas centrais quiser, em qualquer cidade; o cliente pede pelo app e o pedido cai na **central ativa mais próxima**. Se faltar mercadoria, a central **transfere o pedido** para outra. O piloto começa em Goiatuba.

## O que tem aqui

- **App do cliente** (`apps/cliente`, Android e iOS): cadastro, endereço no mapa, catálogo, carrinho, horário, pagamento na entrega, acompanhamento ao vivo, histórico e repetir pedido.
- **Painel** (`apps/painel`, web e Android): o dono vê e controla todas as centrais; o operador cuida da fila de pedidos da sua central.
- **Servidor** (`supabase/`): banco com regras de segurança (RLS), funções de negócio, testes e Edge Functions.
- **Esteira** (`.github/workflows/`): análise, testes, APKs assinados e painel web a cada envio.

## Documentos

- [`docs/ARQUITETURA.md`](docs/ARQUITETURA.md): escopo, dados, segurança e ordem das fases (versão 2).
- [`docs/PROGRESSO.md`](docs/PROGRESSO.md): o que foi feito, o que falta e o próximo passo.
- [`docs/DECISOES.md`](docs/DECISOES.md): decisões importantes, em poucas linhas.
- [`docs/RUNBOOK.md`](docs/RUNBOOK.md): operação, chave dos APKs, backup e contingência.
- [`docs/IMPLEMENTACAO_E_HANDOFF.md`](docs/IMPLEMENTACAO_E_HANDOFF.md): ponto de retomada para o Claude Code.
- [`CLAUDE.md`](CLAUDE.md): regras de trabalho.
