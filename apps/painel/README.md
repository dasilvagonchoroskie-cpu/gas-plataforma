# Painel do dono e das centrais

Um só código que gera **dois aplicativos** (web e Android):

- **Super Central** (só o dono entra): visão geral, pedidos de qualquer central, centrais (ilimitadas, com mapa e faixas de entrega), produtos, preços, usuários, relatórios e auditoria.
- **Central** (só o funcionário da loja entra): fila de pedidos em tempo real (com som), horários, estoque, produtos em falta, entregadores e resumo do dia.

Quem decide o que cada um pode ver ou mudar é o banco (RLS); o aplicativo só escolhe a tela certa e recusa a conta do outro tipo.

Para gerar cada um:

    flutter build apk --flavor supercentral --dart-define=PAINEL=supercentral --dart-define-from-file=../../config/ambiente_dev.json
    flutter build apk --flavor central --dart-define=PAINEL=central --dart-define-from-file=../../config/ambiente_dev.json
    flutter build web --dart-define=PAINEL=supercentral --dart-define-from-file=../../config/ambiente_dev.json

Sem `--flavor` o Android não gera; sem `PAINEL` no web, sai a Central.
