# Guia dos builds de teste Flutter

Este guia descreve os artefatos de validação do projeto, não uma publicação para clientes.

## O que foi compilado

- `build/cliente/app-debug.apk`: APK de depuração somente para Android `arm64`. Usa a assinatura de depuração do Android/Flutter; não é AAB de produção e não deve ser distribuído a clientes.
- `build/painel_proprietario/web/`: saída Web compilada do shell do proprietário.
- `build/painel_central/web/`: saída Web compilada do shell da central.

A execução registrada em [GitHub Actions — run 38461272949](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/actions/runs/38461272949) passou por resolução de dependências, formatação, análise estática, testes, build Android e builds Web. O artefato `plataformas-e-builds-de-teste` tem retenção limitada e expira em 2026-10-20 às 20:24 UTC. O repositório privado é a cópia permanente dos códigos-fonte das plataformas; os binários não foram adicionados ao Git.

## Baixar o artefato

1. Abra a execução do GitHub Actions pelo link acima, usando a conta que tem acesso ao repositório privado.
2. Na parte inferior da página, em **Artifacts**, escolha `plataformas-e-builds-de-teste` para baixar o ZIP.
3. Extraia o ZIP. As pastas `apps/` contêm scaffolds para inspeção; `build/` contém somente as compilações de teste.
4. Para repetir ou gerar novos builds, use o workflow `Preparar plataformas Flutter e builds de teste`. Cada artefato expira após sete dias; não use o ZIP como cópia de segurança do projeto.

## Limites importantes

- Os identificadores `com.example.*`, ícones e imagens são placeholders do template.
- O APK é debug, apenas para teste técnico em aparelho ARM64; não é AAB, não foi publicado e não usa chave de produção.
- Os diretórios dos painéis são compilações Web, não estão hospedados nem publicados. O build Web usa modo release do Flutter, mas não é um deploy de produção.
- O runner Linux gerou os arquivos de projeto iOS, mas não compilou, assinou ou testou o app iOS.
- Nenhuma tela está conectada a autenticação, backend ou dados reais. Não há migrations, Pix automático, credenciais ou autorização implementados.
- Antes de gerar variantes de empresa ou builds de distribuição, o arquiteto deve aprovar identificadores, flavors, branding, assinatura e modelo de isolamento multi-tenant.
