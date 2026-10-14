# Guia para instalar as APKs de prévia

Estas três APKs são builds de **depuração ARM64** para visualizar os shells e a navegação no celular. Foram publicadas como arquivos individuais em um pré-lançamento do repositório privado. Os links exigem uma conta GitHub com acesso ao repositório.

## Downloads diretos

- [App do cliente — APK ARM64](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/releases/download/previa-apks-android-arm64-38507526841/cliente-debug-arm64.apk) — 77.053.903 bytes.
- [Prévia do painel do proprietário — APK ARM64](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/releases/download/previa-apks-android-arm64-38507526841/painel-proprietario-debug-arm64.apk) — 77.049.365 bytes.
- [Prévia do painel da central — APK ARM64](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/releases/download/previa-apks-android-arm64-38507526841/painel-central-debug-arm64.apk) — 77.049.281 bytes.
- [Arquivo SHA256SUMS.txt](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/releases/download/previa-apks-android-arm64-38507526841/SHA256SUMS.txt) — hashes para conferir a integridade.
- [Página do pré-lançamento privado](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/releases/tag/previa-apks-android-arm64-38507526841).

A geração e a conferência do artefato passaram na [execução 38506208860](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/actions/runs/38506208860). Os três APKs foram então publicados separadamente pela [execução 38507526841](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/actions/runs/38507526841). O pré-lançamento privado não tem a expiração de sete dias do artefato temporário do Actions; os links exigem acesso ao repositório.

Hashes SHA-256:

```text
cliente-debug-arm64.apk  8b93631a0d1cad5bd111dc0b3944e3a3faea2a0379385b7968bc69dc09d8df61
painel-proprietario-debug-arm64.apk  1c6a4c5a43ec1de8055c940767698e66e777956f57983992ede210633846eac3
painel-central-debug-arm64.apk  ba30e500b98c3c5b8830107ba79c391b993e6719e85f7e78704c4e975313bcd7
```

## Instalar no Android

- As APKs são somente para aparelhos Android `arm64`.
- Baixe os arquivos diretamente pelos links acima. Se o Android pedir autorização para instalar apps dessa origem, habilite temporariamente apenas para o app de arquivos usado na instalação e desative novamente essa permissão depois.
- Os nomes no celular identificam as prévias como Cliente, Proprietário e Central. Cada APK pode ser removida como qualquer outro app.

## Limites importantes

- São APKs debug com IDs provisórios `com.example.*`; não são builds de produção e não devem ser distribuídas a clientes.
- Não há login, pedidos reais, catálogo, estoque, backend nem uso de dados pessoais. As telas mostram apenas a navegação e os estados de preparação.
- Os APKs Android dos painéis servem somente para prévia responsiva no celular; não decidem se haverá apps móveis de proprietário/central. D-006 continua pendente.
- Não são AABs de loja nem usam assinatura de produção. O projeto iOS não foi compilado ou assinado.
