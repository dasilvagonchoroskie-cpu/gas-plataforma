# Pacote nucleo

Pacote Dart compartilhado pelos aplicativos e serviços que compõem a plataforma.

## Primeiro componente

`ConfiguracaoMarcaEmpresa` valida a configuração pública usada para identificar visualmente uma variante white-label:

- identificador da empresa;
- nome apresentado no aplicativo;
- cor principal em hexadecimal `#RRGGBB`;
- endereço HTTPS público do logo.

A classe normaliza espaços, converte a cor para maiúsculas e rejeita campos ausentes, formatos inválidos e URLs inseguras. A conversão JSON usa os nomes de domínio em `snake_case`.

## Segurança

Esses dados servem para identidade visual e seleção de configuração. O `empresa_id` dentro do aplicativo não autoriza acesso a dados. A autorização será validada no backend/RLS. A URL do logo deve apontar para um recurso público e nunca conter senha, token ou assinatura privada. Nenhum segredo deve ser embutido no APK.

## Verificações

A integração contínua executa `flutter analyze` e `flutter test` para este pacote e os demais pacotes Dart/Flutter localizados em `apps/` e `packages/`.
