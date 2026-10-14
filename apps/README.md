# Aplicativos da plataforma

A arquitetura canônica está em `docs/ARQUITETURA.md`. Há um app Flutter mobile do cliente e um painel Flutter Web unificado para dono e central.

## Estrutura prevista

- `cliente/`: Flutter Android/iOS. Organizar por funcionalidade dentro de `lib/funcionalidades/`.
- `painel/`: Flutter Web único. As funcionalidades do dono e da central ficam no mesmo projeto, separadas por papel em `lib/funcionalidades/`.
- `../packages/nucleo/`: modelos e regras compartilhadas, com nomes de domínio em português.

O painel unificado começou a ser preparado em `apps/painel`. Os shells anteriores em `painel_proprietario/` e `painel_central/` foram preservados temporariamente; seus módulos de navegação já foram copiados para o caminho canônico, e não devem receber funcionalidades novas. Só serão removidos depois da validação do novo pacote e dos fluxos de CI.

## Estado funcional

Os shells atuais não estão conectados a autenticação ou backend e não devem mostrar pedidos ou dados comerciais inventados. O painel unificado inicia em estado de preparação. Nenhum projeto Supabase foi conectado, nenhuma migration foi criada e não existe ambiente de produção.

A implementação deve seguir as fases da arquitetura: banco e segurança (Fase 1), painel do dono (Fase 2), painel da central (Fase 3), app do cliente (Fase 4), push e relatórios (Fase 5), fechamento (Fase 6) e piloto (Fase 7). Não antecipar funcionalidades de fases futuras.
