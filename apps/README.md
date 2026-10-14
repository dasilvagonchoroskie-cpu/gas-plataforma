# Aplicativos e superfícies da plataforma

## Estrutura

- `cliente/`: app Flutter Android/iOS, com Início, Pedidos e Perfil.
- `painel_proprietario/`: painel Flutter Web responsivo para administrar somente o próprio tenant.
- `painel_central/`: painel Flutter Web responsivo para operar a central atribuída.
- `../packages/design_system/`: tema Material 3, navegação responsiva e estados de preparação compartilhados.
- `../packages/nucleo/`: modelos compartilhados e configuração pública de marca.

Os três produtos são shells: não contêm autenticação, autorização efetiva, conexão ao backend nem dados de negócio fictícios. Os avisos de módulos aguardando integração são intencionais.

## Plataformas e builds de teste

As pastas nativas estão versionadas: `cliente/android`, `cliente/ios`, `painel_proprietario/web` e `painel_central/web`. Os painéis são Web nesta etapa; não foram criados apps móveis para eles.

A execução [38506208860](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/actions/runs/38506208860) passou na resolução, formatação, análise, testes e compilou três APKs Android arm64 de depuração, além dos builds Web dos dois painéis. O artefato temporário do Actions contém os três APKs, hashes, scaffolds gerados e builds Web; seu tamanho é 153.447.176 bytes e expira em 2026-10-21 às 03:33:37 UTC. Para evitar depender do ZIP temporário, as três APKs foram publicadas individualmente, com SHA256, no [pré-lançamento privado do GitHub](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/releases/tag/previa-apks-android-arm64-38507526841). Os links diretos e os passos de instalação estão no [guia das APKs](../docs/GUIA_APKS_PREVIA.md).

As APKs são apenas prévias e não definem D-006: os painéis permanecem Web responsivos até decisão de produto. O Android gerado para os painéis existe somente no artefato temporário, não nos projetos versionados. O runner Linux gerou scaffolds de projeto iOS, mas não compilou, assinou ou testou iOS. Os builds Web não foram implantados em hospedagem. O [run anterior 38461272949](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/actions/runs/38461272949) gerou o artefato cliente/Web inicial documentado no [guia de builds de teste](../docs/GUIA_BUILDS_TESTE.md).

## Dependências

Os `pubspec.lock` dos três apps e dos dois pacotes privados são gerados pelo workflow `Fixar dependências Flutter`, que resolve, analisa e testa os projetos antes de registrá-los. Isso permite repetir as versões testadas; não substitui a atualização periódica e revisão de dependências.

## Limites e revisão pendente

- `com.example.*`, ícones e imagens genéricos são placeholders, não identificadores de produção.
- Não há chave de assinatura de produção; não gerar ou distribuir AAB/release antes da revisão do arquiteto.
- Variantes por empresa, IDs finais, identidade visual, assinatura e publicação precisam de revisão do arquiteto sênior.
- Não há projeto Supabase, migrations, regras de negócio, autenticação, papéis ou autorização. Fechar D-002–D-007, D-010 e D-011 antes de qualquer migration ou integração.
- A identidade da empresa no app nunca substitui autorização do servidor/RLS. O proprietário fica limitado ao próprio tenant; não há administrador global no escopo.
