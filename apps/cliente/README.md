# App do cliente

Shell Flutter compartilhado pelas variantes white-label Android/iOS. A navegação inicial separa Início, Pedidos e Perfil; ainda não há autenticação, catálogo, endereço, pedidos ou dados simulados.

- Usa o tema e os estados de preparação do pacote `design_system` e os modelos compartilhados do pacote `nucleo`.
- Os diretórios nativos Android e iOS estão versionados. O workflow gerou um APK de depuração `arm64` para teste técnico; consulte [`docs/GUIA_BUILDS_TESTE.md`](../../docs/GUIA_BUILDS_TESTE.md) para obtê-lo.
- As dependências estão fixadas em `pubspec.lock`, gerado pelo workflow após análise e testes.
- A configuração de `empresa_id` é apenas seleção de marca; não concede autorização. Os módulos aguardam a revisão de autenticação e RLS.
- `com.example.cliente`, ícones e imagens do template são provisórios. IDs de produção, flavors por empresa, assinatura e publicação ficam para revisão do arquiteto.

O APK existente é de depuração, não é AAB de produção e não deve ser distribuído a clientes. Nenhum APK de produção foi gerado.
