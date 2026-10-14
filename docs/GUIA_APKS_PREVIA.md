# Guia para instalar as APKs de prévia

A execução [38506208860](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/actions/runs/38506208860) foi concluída com sucesso. O artefato privado `previa-tres-apks-android-arm64` contém as três APKs arm64 de depuração, os arquivos de checksum, os scaffolds temporários Android/iOS/Web e os builds Web dos painéis. O arquivo compactado tem 153.447.176 bytes e expira em **21/10/2026 às 03:33:37 UTC (00:33:37 em Goiatuba)**.

Estas são três APKs de **depuração** para visualizar os shells e a navegação no celular. As APKs dos painéis servem somente à prévia responsiva: não mudam a decisão D-006 sobre manter o produto como Web ou criar app móvel.

## Baixar

1. Abra a [execução de geração das três APKs](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/actions/runs/38506208860) em uma conta com acesso ao repositório privado.
2. Na área **Artifacts**, baixe o arquivo `previa-tres-apks-android-arm64` e extraia o ZIP.
3. As APKs ficam em `build/apks/`:
   - `cliente-debug-arm64.apk` — app do cliente;
   - `painel-proprietario-debug-arm64.apk` — prévia do painel do proprietário;
   - `painel-central-debug-arm64.apk` — prévia do painel da central.
4. `build/apks/SHA256SUMS.txt` contém os hashes para conferir a integridade dos três APKs. O artefato fica disponível até 21/10/2026 às 03:33:37 UTC; depois disso, o GitHub o remove automaticamente.

## Instalar no Android

- As APKs são somente para aparelhos Android `arm64`.
- Transfira ao celular apenas os arquivos da execução do repositório privado e abra cada APK pelo app de arquivos do aparelho.
- Se o Android pedir autorização para instalar apps dessa origem, habilite temporariamente apenas para o app de arquivos usado na instalação. Depois, desative novamente essa permissão nas configurações do Android.
- Os nomes na tela do aparelho identificam as prévias como Cliente, Proprietário e Central. Cada APK é independente e pode ser removida como qualquer outro app.

## O que esperar e o que não fazer

- As três telas são shells de interface; não existe login, pedido, catálogo, estoque ou conexão com servidor. A navegação mostra as áreas planejadas e mensagens de que aguardam integração.
- Não use dados reais de clientes e não distribua estas APKs. São debug, usam IDs provisórios `com.example.*` e não estão assinadas para produção.
- As APKs não são AABs de loja. Nenhuma chave de produção foi criada.
- A prévia dos painéis no Android não decide que eles serão produtos móveis; D-006 e a revisão do arquiteto continuam pendentes.
- Não foi compilado iOS. Os builds Web dos painéis são separados das APKs e não estão publicados.
