# Aplicativos

- `cliente/` — app do cliente (Flutter, Android e iOS). Rotas com go_router, estado com Riverpod.
- `painel/` — painel único do dono e das centrais (Flutter Web e Android). Depois do login, mostra a interface do papel do usuário: dono, operador de central ou "sem acesso".

Os dois usam os pacotes compartilhados de `../packages/` (`nucleo`, `design_system`, `dados`). As funcionalidades ficam em `lib/funcionalidades/<nome>/`.

Os builds leem o endereço do servidor e a chave pública de `../config/ambiente_dev.json`:

    flutter build apk --release --dart-define-from-file=../../config/ambiente_dev.json

Sem esse arquivo, o app abre uma tela avisando que está sem configuração.
