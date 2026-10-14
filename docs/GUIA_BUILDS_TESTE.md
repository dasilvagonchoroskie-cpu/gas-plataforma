# Guia dos builds de teste Flutter

Este documento registra como os builds foram validados; não descreve uma publicação para clientes.

## APKs individuais para prévia no celular

Para baixar cada APK diretamente, sem ZIP, consulte o [guia das três APKs de prévia](GUIA_APKS_PREVIA.md). Os arquivos estão como assets individuais em um pré-lançamento do repositório privado e exigem acesso ao GitHub.

## Compilação validada

A [execução 38506208860](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/actions/runs/38506208860) passou por resolução de dependências, formatação, análise estática e testes; compilou três APKs Android debug `arm64` e os dois builds Web dos painéis. O artefato temporário do Actions também contém os scaffolds gerados para inspeção e expira sete dias depois da conclusão. O [run 38461272949](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/actions/runs/38461272949) foi uma execução anterior que gerou apenas o APK do cliente e os builds Web.

O código-fonte das plataformas do cliente e Web dos painéis fica versionado no repositório. Os binários não ficam na árvore de código: as três APKs de prévia estão anexadas separadamente à [release privada](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/releases/tag/previa-apks-android-arm64-38507526841). Os builds Web continuam sendo artefatos de teste e não estão hospedados.

## Como repetir a compilação

Use o workflow `Preparar plataformas Flutter e builds de teste`. Ele executa resolução, formatação, análise e testes; compila APKs debug `arm64` e Web release; e guarda um artefato temporário por sete dias. Não use esse ZIP temporário como cópia de segurança do código. A publicação individual de APKs nesta prévia foi feita em um pré-lançamento privado e não é automática para novas execuções.

## Limites

- Os IDs `com.example.*`, ícones e imagens são placeholders do template.
- APKs são debug, arm64 e assinados com configuração de depuração; não são AABs nem builds para distribuição.
- Os APKs Android dos painéis servem apenas para prévia responsiva e não decidem D-006.
- O runner Linux gerou arquivos de projeto iOS, mas não compilou, assinou nem testou iOS.
- Os painéis Web não foram implantados. Nenhum app está conectado a autenticação, backend ou dados reais.
- Antes de releases de produção, o arquiteto deve aprovar IDs, flavors, branding, assinatura, segurança multi-tenant e o fluxo de distribuição.
