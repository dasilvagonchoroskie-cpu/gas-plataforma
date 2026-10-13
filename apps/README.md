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

O [run 38461272949](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/actions/runs/38461272949) passou na resolução, formatação, análise, testes e compilou um APK Android arm64 de depuração e os dois painéis Web. O artefato `plataformas-e-builds-de-teste` expira em 2026-10-20 às 20:24 UTC; os binários não ficam no Git nem foram publicados. Consulte o [guia de builds de teste](../docs/GUIA_BUILDS_TESTE.md).

O runner Linux gerou os arquivos de projeto iOS, mas não compilou, assinou ou testou iOS. Os builds Web não foram implantados em hospedagem.

## Dependências

Os `pubspec.lock` dos três apps e dos dois pacotes privados são gerados pelo workflow `Fixar dependências Flutter`, que resolve, analisa e testa os projetos antes de registrá-los. Isso permite repetir as versões testadas; não substitui a atualização periódica e revisão de dependências.

## Limites e revisão pendente

- `com.example.*`, ícones e imagens genéricos são placeholders, não identificadores de produção.
- Não há chave de assinatura de produção; não gerar ou distribuir AAB/release antes da revisão do arquiteto.
- Variantes por empresa, IDs finais, identidade visual, assinatura e publicação precisam de revisão do arquiteto sênior.
- Não há projeto Supabase, migrations, regras de negócio, autenticação, papéis ou autorização. Fechar D-002–D-007, D-010 e D-011 antes de qualquer migration ou integração.
- A identidade da empresa no app nunca substitui autorização do servidor/RLS. O proprietário fica limitado ao próprio tenant; não há administrador global no escopo.
