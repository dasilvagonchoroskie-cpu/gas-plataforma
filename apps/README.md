# Aplicativos e superfícies da plataforma

## Estrutura

- `cliente/`: app Flutter para Android e iOS, com as telas iniciais Início, Pedidos e Perfil.
- `painel_proprietario/`: painel Flutter Web para a administração do próprio tenant.
- `painel_central/`: painel Flutter Web para a operação da central atribuída.
- `../packages/design_system/`: tema Material 3 e componentes compartilhados dos painéis.
- `../packages/nucleo/`: núcleo Dart compartilhado.

Os três produtos continuam sendo shells de interface: não contêm autenticação, integração com backend, autorização efetiva nem dados de negócio fictícios. Os avisos de módulos aguardando integração são intencionais.

## Estado das plataformas

Os diretórios de plataforma foram gerados com Flutter 3.47.7 e registrados no repositório: `cliente/android`, `cliente/ios`, `painel_proprietario/web` e `painel_central/web`. Os painéis são apenas Web nesta etapa; não foram criados projetos móveis para eles.

A execução [38461272949](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/actions/runs/38461272949) validou dependências, formatação, análise estática e testes dos apps/pacotes; compilou um APK Android de depuração para `android-arm64` e os builds Web de release dos dois painéis. Os builds estão somente no artefato de CI `plataformas-e-builds-de-teste`, disponível até 2026-10-20 às 20:24 UTC; não são publicados no repositório nem implantados. O artefato também serve para inspecionar as pastas nativas e Web geradas.

O runner Linux apenas gerou os arquivos de projeto iOS: **nenhum build, assinatura ou teste iOS foi executado**. Os builds Web de release são saídas de compilação de teste, não uma publicação em hospedagem.

## Limites e revisão pendente

- `com.example.cliente` e demais valores `com.example.*` são identificadores provisórios do template, não identificadores de produção. A configuração de empresas, flavors/variantes, ícones finais e IDs de loja depende da revisão do arquiteto sênior.
- O projeto Android contém configuração de assinatura de depuração do template; não há chave de produção nem material de assinatura no repositório. Não gerar ou distribuir release/AAB antes da aprovação do fluxo de assinatura.
- Os ícones e imagens iniciais são recursos genéricos do template e devem ser substituídos após aprovação da identidade visual.
- Arquivos locais e efêmeros de Flutter, Gradle e Xcode, builds e segredos estão cobertos pelo `.gitignore`; nunca versionar `local.properties`, configurações de ambiente ou credenciais.
- `pubspec.lock` dos apps ainda não foi registrado. Versionar os lockfiles de app quando a política de dependências for definida e antes de estabilizar releases.
- Não há projeto Supabase provisionado, migrations, integração de backend, regras de negócio, papéis ou autorização implementados. Fechar e aprovar D-002–D-007, D-010 e D-011 e o modelo de isolamento multi-tenant antes de qualquer migration ou integração.

## Princípios

A configuração pública de marca pode selecionar a apresentação white-label; nunca concede autorização. O proprietário deve permanecer limitado ao próprio tenant, e não se cria um papel de administrador global da plataforma. Credenciais privilegiadas e segredos não podem ser embutidos nos apps ou nos artefatos distribuídos.
