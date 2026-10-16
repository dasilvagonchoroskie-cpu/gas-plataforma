# Progresso

**Atualizado:** 2026-10-16
**Etapa:** Fases 1 a 5 construídas no ambiente de desenvolvimento, com ficha de cadastro e crediário (arquitetura versão 3); começando a Fase 6 (fechamento).

## Objetivo

Plataforma de pedidos de uma revenda de gás e água mineral: app do cliente (Android/iOS), painel do dono e painel das centrais (web e Android), com backend Supabase. O dono abre quantas centrais quiser; o pedido cai na central mais próxima do cliente, e a central pode transferir o pedido para outra. Arquitetura completa em `docs/ARQUITETURA.md` (versão 3).

## Feito

- **Banco (Fase 1):** tabelas, RLS em todas, regras de negócio no servidor (central mais próxima, faixas de entrega, agenda com vagas, pedido sem duplicar, transferência, estoque, relatórios, auditoria), segredos no Vault. 155 testes pgTAP passando no Postgres local e no Supabase completo do GitHub.
- **Servidor:** Edge Functions `cadastro`, `admin-usuarios`, `excluir-conta`, `endereco`, `notificar` e `assinatura-android` publicadas no projeto de desenvolvimento e testadas (cadastro cria conta; chamadas sem autorização são recusadas; aviso lê o segredo do Vault).
- **Pacotes compartilhados:** `nucleo` (regras e modelos), `design_system` (visual) e `dados` (acesso ao Supabase).
- **Ficha e crediário (versão 3):** ficha obrigatória no app (documentos, moradia, trabalho, renda, referências e fotos), aprovação na Super Central (ou nas centrais, se o dono liberar, com teto), fiado com limite, conta de quem deve, pagamentos, ajustes e extrato para o cliente.
- **Painel do dono — Super Central (Fase 2):** visão geral, pedidos de qualquer central, centrais ilimitadas com mapa e faixas, produtos com foto, preços por central, usuários, relatórios com cópia para planilha e auditoria.
- **Painel da central (Fase 3):** fila em tempo real com som, detalhe do pedido, transferência, entregadores, horários e bloqueios, estoque, disponibilidade e resumo do dia.
- **App do cliente (Fase 4):** cadastro, endereços (CEP, mapa, GPS), catálogo da central mais próxima, carrinho, horário, pagamento na entrega, acompanhamento ao vivo, histórico, repetir pedido, perfil e exclusão de conta.
- **Fase 5:** relatórios do dono prontos; notificações push prontas no servidor, aguardando o projeto Firebase.
- **Esteira (GitHub Actions):** formatação automática, análise estática sem avisos e testes de todos os pacotes; relatório em português no ramo `ci-relatorio`; testes do banco no ramo `ci-relatorio-banco`; APKs assinados e painel web no ramo `entregas`.
- **Ambiente de desenvolvimento:** dados de teste carregados (3 centrais — só Goiatuba ativa —, 5 produtos, preços, horários e faixas) e conta de administrador criada (`platformadevendas2026@gmail.com`).

## Resultado da última validação (16/10/2026, build 21)

- Análise estática: nenhum aviso em nenhum pacote.
- Testes Flutter: 60 passando (nucleo 39, design_system 5, dados 6, cliente 4, painel 6).
- Testes do banco: 155 passando (local e no Supabase completo do GitHub).
- APKs do cliente e do painel assinados com a chave da revenda (conferido).

## Falta

1. Projeto Firebase (no nome do dono) para as notificações: cadastrar o segredo `FCM_CONTA_SERVICO` no painel do Supabase e incluir o `google-services.json` nos apps.
2. SMTP próprio (e-mail de recuperação de senha) e domínio.
3. Nome, logotipo e cores da revenda (hoje: "Gás e Água", cor padrão).
4. Política de privacidade e termos publicados (`/gas-agua/privacidade.html` e `/gas-agua/termos.html`), incluindo a ficha de cadastro e o crediário (dados: razão social, CNPJ e e-mail da revenda).
5. Publicar o painel web (hospedagem estática) e testar de ponta a ponta com o operador.
6. Fase 6: backup e restauração testados, ícones e telas das lojas, Google Play (teste fechado de 14 dias) e TestFlight.
7. Produção no nome do dono (Supabase Pro), na fase prevista.

## Próximo passo

Evandro testa os APKs (build 21) no celular: ficha, aprovação na Super Central, pedido no fiado e pagamento. Depois, seguir os itens de "Falta" na ordem.
