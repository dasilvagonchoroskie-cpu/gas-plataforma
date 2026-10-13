# App do cliente

Shell Flutter compartilhado pelas variantes white-label Android/iOS. A navegação inicial separa Início, Pedidos e Perfil; não há ainda autenticação, catálogo, endereço, pedido ou dados simulados.

- Usa o tema e os estados de preparação do pacote `design_system`.
- Usa o núcleo comum `nucleo` para modelos compartilhados, sem confiar em `empresa_id` como autorização.
- Os módulos ficam deliberadamente sem backend até aprovação do modelo de tenant/RLS e da autenticação.
- Identificadores Android/iOS, flavors por empresa, ícones, assinatura e publicação precisam ser definidos com o arquiteto; nenhum APK de produção foi gerado.

Para execução e publicação, aguardar a criação das plataformas nativas pelo fluxo de bootstrap e as configurações aprovadas. Este shell não é uma versão pronta para clientes.
