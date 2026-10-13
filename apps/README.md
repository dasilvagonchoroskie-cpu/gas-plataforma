# Aplicativos planejados

Esta pasta está reservada para os apps Flutter. Nenhum template incompleto foi adicionado.

## Estrutura proposta

- `cliente/`: app Android/iOS, mesma base de código e variantes white-label.
- `painel/`: painel web, com telas e permissões validadas no backend; o escopo final depende da decisão D-006.

Cada app deve separar apresentação, domínio e acesso a dados por funcionalidade. O identificador de empresa usado para selecionar a marca é configuração pública, não autorização. Credenciais privilegiadas não podem entrar no app nem nos artefatos Android/iOS.

Antes de gerar variantes de produção, confirmar com o arquiteto os identificadores de pacote, as configurações por empresa, o processo de assinatura e o armazenamento das chaves fora do repositório. O painel web e a publicação também precisam de provedor e fluxo de deploy aprovados.
