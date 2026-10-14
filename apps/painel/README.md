# Painel web unificado

Este é o caminho canônico do painel Flutter Web para o dono e as centrais, conforme `docs/ARQUITETURA.md`.

As funcionalidades ficam organizadas em `lib/funcionalidades/`. O conteúdo dos shells anteriores foi preservado em módulos de dono e central; o login e o encaminhamento por papel serão implementados na ordem das fases 2 e 3. Até lá, a tela inicial não concede acesso nem apresenta dados fictícios.

As pastas antigas `apps/painel_proprietario` e `apps/painel_central` permanecem temporariamente como cópias de referência durante a validação estrutural. Não iniciar funcionalidades novas nelas. A remoção das cópias antigas só ocorrerá depois que o painel unificado e o CI forem validados.
