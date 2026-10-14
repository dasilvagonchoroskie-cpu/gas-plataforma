# Plataforma de pedidos de gás e água: arquitetura e plano de construção

**Versão 1 · 13/10/2026 · Piloto: central de Goiatuba**

## 1. Leia primeiro (instruções para o Claude Code)

- Leia este documento inteiro antes de escrever qualquer código.
- Siga a ordem da seção 11. Não pule fases e não crie funções fora do escopo da seção 3.
- O desenvolvedor não lê código nem inglês. Antes e depois de cada mudança, explique em português simples, em poucas linhas, o que vai fazer e o que fez.
- Faça commits pequenos, com mensagens em português.
- Ao fim de cada etapa, atualize `docs/PROGRESSO.md` com o que foi feito, o que falta e o próximo passo. O uso do Claude tem limite por sessão e por semana, e esse arquivo permite retomar o trabalho sem perder contexto.
- Nunca coloque senhas ou chaves secretas no código. Nunca altere o banco de produção direto: tudo passa por migrations versionadas.
- Antes de dizer que terminou algo, rode a análise estática e os testes e mostre o resultado.
- Nomes de domínio (tabelas, colunas, classes) em português, sem acento: `snake_case` no banco e `PascalCase` em Dart. O código do próprio framework fica em inglês.

## 2. Contexto

Um depósito de gás de cozinha (revenda) que também vende água mineral atende três municípios de Goiás: Goiatuba, Itumbiara e Bom Jesus de Goiás. Não é um marketplace: existe um único vendedor.

Cada município tem uma central, que recebe os pedidos da cidade e organiza as entregas. O dono vê e controla todas as centrais. Os clientes pedem pelo aplicativo e escolhem o horário de entrega.

Hierarquia: dono (pai) → centrais (filhos) → clientes de cada cidade (netos). No piloto, só a central de Goiatuba fica ativa. As outras centrais são criadas pelo próprio dono, no painel, sem programação nova e sem atualizar o app nas lojas.

Princípio de qualidade: sólido e simples. Um backend só (sem microsserviços), permissões no banco, backup testado e testes nas regras críticas. Sem gambiarra e sem complexidade que o porte do negócio não pede.

## 3. Escopo

### Entra no piloto

- Painel do dono (web): centrais, produtos, preços por central, usuários, visão geral e relatórios.
- Painel da central (web): fila de pedidos em tempo real, mudança de status, janelas de entrega e capacidade, estoque e cadastro de entregadores.
- App do cliente (Android e iOS): cadastro, cidade e endereço, catálogo, carrinho, escolha de data e horário, pedido, acompanhamento, histórico e repetir o último pedido.
- Notificações push a cada mudança de status.
- Pagamento na entrega: dinheiro (com troco), cartão na maquininha ou Pix na entrega.

### Previsto na arquitetura, fora do piloto (módulos à parte; o banco já fica preparado)

- App do entregador (o papel entregador e o campo `pedidos.entregador_id` já existem).
- Pix automático, com gateway e confirmação por webhook.
- Lembrete automático de recompra.

## 4. Árvore de arquitetura

```text
DONO (painel web) ........ vê e controla tudo
├── Central Goiatuba ........ painel da central (ATIVA no piloto)
│   └── Clientes de Goiatuba ........ app do cliente
├── Central Itumbiara ........ criada pelo dono no painel
│   └── Clientes de Itumbiara ........ mesmo app
└── Central Bom Jesus de Goiás ........ criada pelo dono no painel
    └── Clientes de Bom Jesus ........ mesmo app

Apps (Flutter)                   Backend (Supabase, um projeto só)
┌──────────────────┐             ┌────────────────────────────────────┐
│ App do cliente   │──┐          │ Auth: login                        │
│ Android e iOS    │  │          │ Postgres + RLS: dados e permissões │
└──────────────────┘  ├────────▶ │ Realtime: pedidos ao vivo          │
┌──────────────────┐  │          │ Storage: fotos dos produtos        │
│ Painel web       │──┘          │ Edge Functions: push e tarefas     │
│ dono e central   │             └──────────────────┬─────────────────┘
└──────────────────┘                                │
                                    Firebase Cloud Messaging (só push)
```

### Regras da árvore

1. Existe um único app do cliente. A cidade escolhida liga o cliente a uma central.
2. Centrais são dados no banco, nunca código. Nenhuma cidade fica fixa no código dos apps.
3. Todo dado operacional carrega `central_id`, e as permissões são aplicadas no próprio banco (RLS).
4. Criar uma central no painel do dono é suficiente para ela aparecer no app, sem nova versão nas lojas.
## 5. Stack (decisões fechadas)

- App do cliente: Flutter (Android e iOS), com Riverpod para estado, go_router para navegação e supabase_flutter para falar com o backend.
- Painel web: Flutter Web, no mesmo repositório (monorepo), compartilhando o pacote `nucleo` (modelos e regras).
- Backend: Supabase (Postgres, Auth, Realtime, Storage e Edge Functions). Produção em uma organização no nome do dono, no plano Pro. Desenvolvimento em um projeto gratuito, em organização separada, para não pagar projeto extra.
- Push: Firebase Cloud Messaging, só para notificações (nenhum outro serviço do Firebase).
- Hospedagem do painel web: hospedagem estática (por exemplo, Cloudflare Pages), com domínio próprio.
- Pix automático (módulo futuro): gateway (por exemplo, Asaas ou Mercado Pago) com webhook em uma Edge Function.
- Monitoramento: captura de erros nos apps (por exemplo, Sentry), logs das Edge Functions e alerta de erro por e-mail.
- Qualidade: `flutter analyze`, testes de unidade, testes de RLS e GitHub Actions.

## 6. Perfis e permissões

| Papel | O que pode |
|---|---|
| `cliente` | Ver catálogo e preços da central da sua cidade; criar pedidos pela função `criar_pedido`; ver e cancelar (só enquanto novo) os próprios pedidos; gerenciar os próprios endereços; excluir a própria conta |
| `operador_central` | Na própria central: ver e atualizar pedidos, janelas, estoque e entregadores |
| `entregador` (reservado) | Ver só as entregas atribuídas a ele (módulo futuro) |
| `dono` | Tudo, em todas as centrais: centrais, usuários, produtos, preços, relatórios e auditoria |

### Implementação

- Tabela `perfis` ligada ao login (`auth.users`) com o campo `papel`; a tabela `operadores_central` liga operador e central.
- Funções auxiliares `eh_dono()` e `central_do_operador()`, com `security definer` e `search_path` fixo.
- RLS ligada em todas as tabelas: sem política, sem acesso.
- A chave `service_role` nunca vai para os apps. Preço, total, taxa e capacidade da janela são calculados no servidor; o app nunca envia valores.

## 7. Modelo de dados

Regras gerais: todo valor em dinheiro é guardado em centavos (número inteiro), com sufixo `_centavos`. Datas e horas ficam em UTC no banco e são exibidas no fuso `America/Sao_Paulo`. Todas as tabelas têm RLS.

- `perfis`: `id` (igual ao id do login), `nome`, `telefone`, `papel`, `criado_em`
- `centrais`: `id`, `nome`, `cidade`, `uf`, `ativa`, `whatsapp`, `endereco`, `criado_em`
- `operadores_central`: `perfil_id`, `central_id`
- `areas_entrega`: `id`, `central_id`, `bairro`, `taxa_entrega_centavos`, `ativa`
- `produtos`: `id`, `nome`, `categoria` (`gas` ou `agua`), `descricao`, `foto_url`, `troca_vasilhame` (verdadeiro quando o cliente entrega o vasilhame vazio), `ativo`
- `precos_central`: `produto_id`, `central_id`, `preco_centavos`, `disponivel`
- `estoque_central`: `produto_id`, `central_id`, `cheios`, `vazios`, `alerta_minimo`
- `movimentos_estoque`: `id`, `produto_id`, `central_id`, `tipo`, `quantidade`, `motivo`, `pedido_id` (opcional), `por_perfil_id`, `criado_em`
- `janelas_entrega`: `id`, `central_id`, `dia_semana`, `hora_inicio`, `hora_fim`, `capacidade`, `ativa`
- `bloqueios_agenda`: `id`, `central_id`, `data`, `janela_id` (opcional), `motivo`
- `enderecos`: `id`, `cliente_id`, `apelido`, `cep`, `logradouro`, `numero`, `bairro`, `cidade`, `complemento`, `referencia`, `central_id`
- `pedidos`: `id`, `numero` (sequencial por central, gerado no banco), `cliente_id`, `central_id`, dados do endereço copiados no momento do pedido, `data_entrega`, `janela_id`, `status`, `forma_pagamento`, `troco_para_centavos`, `observacao`, `subtotal_centavos`, `taxa_entrega_centavos`, `total_centavos`, `entregador_id` (opcional), `criado_em`, `atualizado_em`
- `itens_pedido`: `id`, `pedido_id`, `produto_id`, `quantidade`, `preco_unitario_centavos` (copiado no momento do pedido)
- `historico_status`: `id`, `pedido_id`, `status`, `por_perfil_id`, `criado_em`
- `dispositivos_push`: `id`, `perfil_id`, `token`, `plataforma`, `atualizado_em`
- `auditoria`: `id`, `por_perfil_id`, `acao`, `tabela`, `registro_id`, `antes`, `depois`, `criado_em`

Tipos: `status_pedido` (`novo`, `confirmado`, `em_rota`, `entregue`, `cancelado`) e `forma_pagamento` (`dinheiro`, `cartao_na_entrega`, `pix_na_entrega`).

### Funções do banco (RPC)

- `criar_pedido(...)`: numa única transação, valida central ativa, bairro atendido, janela com vaga e sem bloqueio e produtos disponíveis; calcula subtotal, taxa e total; grava pedido, itens e histórico. A checagem de capacidade usa trava para impedir que duas pessoas ocupem a última vaga.
- `janelas_disponiveis(central_id, data)`: devolve só os horários com vaga.
- `mudar_status_pedido(pedido_id, novo_status)`: valida as transições permitidas e quem pode fazê-las; ao entregar, baixa o estoque (cheios menos a quantidade; vazios mais a quantidade quando for troca de vasilhame).
- `criar_central(...)`: só o dono. Cria a central, copia preços e janelas de uma central modelo e vincula o primeiro operador.

Índices: pedidos (`central_id`, `status`, `criado_em`), pedidos (`cliente_id`, `criado_em`) e `precos_central` (`central_id`).

## 8. Telas e fluxos

### App do cliente

Abertura, login e cadastro (e-mail e senha; telefone obrigatório), escolha da cidade (lista vinda das centrais ativas), endereços (CEP com preenchimento automático e checagem do bairro atendido), início com catálogo de gás e água, carrinho, escolha de data e horário, resumo e forma de pagamento, acompanhamento do pedido em tempo real, meus pedidos (com repetir em um toque), perfil e exclusão da conta, e botão para falar com a central pelo WhatsApp.

### Painel da central

Login, fila de pedidos em quadro (novos, confirmados, em rota, entregues) com aviso sonoro de pedido novo, detalhe do pedido, janelas e capacidade, bloqueios de agenda, estoque (ajustes com motivo), preços da central, entregadores e resumo do dia.

### Painel do dono

Login, visão geral com um cartão por central (pedidos de hoje e faturamento), centrais (lista, nova central, editar, ativar e desativar), produtos, preços por central, usuários (criar operador e vincular a uma central), relatórios por período, central e produto, e auditoria.

### Requisitos de uso

Telas simples, botões e textos grandes (muitos clientes são idosos), só português do Brasil e no máximo três toques para repetir o último pedido.

## 9. Segurança, qualidade e operação

- RLS em todas as tabelas e testes automáticos provando que o operador da central A não enxerga dados da central B e que o cliente só enxerga o que é dele.
- Migrations versionadas (Supabase CLI) em `supabase/migrations`; produção só muda por migration.
- Backup: o plano Pro faz backup diário; além disso, exportação semanal do banco guardada fora do Supabase e teste de restauração antes de abrir o piloto.
- Segredos só em variáveis de ambiente e nos segredos do Supabase e do GitHub, nunca no repositório.
- Dados pessoais (nome, telefone, endereço) tratados conforme a LGPD: política de privacidade publicada, coleta só do necessário e exclusão de conta dentro do app (as lojas exigem; confirmar na revisão).
- Testes de unidade nas regras de preço, taxa, capacidade e estoque, e testes de RLS em `supabase/tests`.
- Piloto seguro: a central continua recebendo pelo WhatsApp em paralelo no começo, e o app abre primeiro para poucos clientes.
- `docs/RUNBOOK.md` com o passo a passo para restaurar backup, trocar chaves e o que fazer se o app ou o banco ficarem fora do ar.

## 10. Estrutura do repositório

```text
gas-plataforma/
├── CLAUDE.md                 resumo e regras (seção 1 deste documento)
├── docs/
│   ├── ARQUITETURA.md        este documento
│   ├── PROGRESSO.md          o que foi feito e o próximo passo
│   ├── DECISOES.md           decisões importantes, em poucas linhas
│   └── RUNBOOK.md            backup, restauração e o que fazer se cair
├── supabase/
│   ├── migrations/           mudanças do banco, versionadas
│   ├── functions/            Edge Functions (push, tarefas agendadas)
│   ├── tests/                testes de RLS
│   └── seed.sql              dados de teste
├── packages/
│   └── nucleo/               modelos e regras compartilhadas (Dart)
└── apps/
    ├── cliente/              Flutter mobile (Android e iOS)
    └── painel/               Flutter Web (dono e central)
```

Dentro de cada app, organizar por funcionalidade: `lib/funcionalidades/<nome>/` com telas, estado e repositório.

## 11. Ordem de construção

1. **Fase 0:** repositório, ambientes dev e prod, integração contínua, `docs/PROGRESSO.md` e este documento na raiz.
2. **Fase 1 — banco:** migrations das tabelas, RLS, funções (RPC), `seed.sql` (3 centrais, produtos e preços de teste) e testes de RLS.
3. **Fase 2 — painel do dono:** login, centrais (incluindo criar central), produtos, preços e usuários.
4. **Fase 3 — painel da central:** fila em tempo real, status, janelas, estoque e entregadores.
5. **Fase 4 — app do cliente:** cadastro, cidade e endereço, catálogo, carrinho, janela, pedido, acompanhamento e histórico.
6. **Fase 5:** notificações push e relatórios do dono.
7. **Fase 6 — fechamento:** testes, backup e restauração, política de privacidade, exclusão de conta, ícones e telas das lojas. Se a conta do Google Play for pessoal e nova, o teste fechado exige 12 testadores por 14 dias seguidos, então começar essa etapa antes do fim do desenvolvimento. No iPhone, usar TestFlight.
8. **Fase 7 — piloto em Goiatuba:** treinar o dono e o operador (manual curto em português), acompanhar os primeiros dias e ajustar.

## 12. Contas e custos recorrentes (tudo no nome do dono)

- Supabase Pro: US$ 25 por mês, mais uso extra se passar da cota.
- Apple Developer Program: US$ 99 por ano.
- Google Play: US$ 25, pagos uma única vez.
- Domínio: cerca de R$ 40 por ano.
- Firebase Cloud Messaging e hospedagem estática do painel: podem ficar em planos gratuitos (confirmar os limites na contratação).

## 13. Glossário

- **RLS:** regras que o banco aplica linha por linha para decidir quem pode ver ou alterar cada dado.
- **RPC:** função guardada no banco que o app chama para fazer uma operação completa e segura.
- **Edge Function:** pequeno programa que roda no Supabase, usado para enviar notificações e tarefas agendadas.
- **Migration:** arquivo versionado que descreve uma mudança no banco, para tudo ser reproduzível.
- **Monorepo:** um único repositório com todos os apps e pacotes.
- **Webhook:** aviso automático que um serviço (por exemplo, o gateway de Pix) envia ao nosso sistema.
- **Seed:** dados de teste carregados no banco de desenvolvimento.
