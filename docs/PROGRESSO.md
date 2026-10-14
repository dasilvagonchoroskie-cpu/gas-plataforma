# Progresso

**Atualizado:** 2026-10-14

## Feito

- Criado o repositório privado `gas-plataforma`; nenhum repositório antigo foi acessado ou alterado.
- Registradas a arquitetura multi-tenant white-label e as decisões já aprovadas. A matriz de acesso e o handoff continuam como propostas para revisão do arquiteto, não como autorização para criar migrations.
- Criado `packages/nucleo` com modelo de configuração pública de marca, validação e `Dinheiro` para representar/formatar valores em centavos inteiros sem ponto flutuante; o componente monetário tem testes unitários. `packages/design_system` oferece tema Material 3, navegação responsiva e estados seguros de preparação.
- Criados três shells Flutter: `apps/cliente`, `apps/painel_proprietario` e `apps/painel_central`, sem autenticação, autorização, backend ou dados de negócio simulados.
- Geradas e versionadas as plataformas Android/iOS do app do cliente e Web dos dois painéis. IDs `com.example.*` e recursos visuais genéricos são placeholders, não configurações de produção.
- Adicionados ao Git os cinco `pubspec.lock` (três apps e dois pacotes privados) pelo workflow `Fixar dependências Flutter`, após Flutter 3.47.7 resolver dependências, formatar, analisar e passar os testes. A execução [38464776457](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/actions/runs/38464776457) foi bem-sucedida; os lockfiles foram registrados no commit `fbced56000cb320f33f43c85f43c1d2f4870872a`.
- A execução anterior [38461272949](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/actions/runs/38461272949) validou formatação, análise e testes; compilou o primeiro APK do cliente e os builds Web. Seu artefato temporário expira em 2026-10-20 às 20:24 UTC; os builds atuais estão descritos nos guias abaixo.
- A execução [38506208860](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/actions/runs/38506208860) passou: compilou três APKs Android debug `arm64` e os dois painéis Web após formatação, análise e testes. O artefato ZIP temporário inclui APKs, hashes, scaffolds e builds Web; tamanho 153.447.176 bytes, expiração em 2026-10-21 às 03:33:37 UTC.
- As três APKs foram então publicadas como arquivos individuais em um pré-lançamento do repositório privado: [execução 38507526841](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/actions/runs/38507526841). Links diretos, hashes e instruções estão no [guia das APKs](GUIA_APKS_PREVIA.md). São debug ARM64; as prévias Android dos painéis não decidem D-006. O runner Linux não compilou nem assinou iOS.
- A pasta iOS foi gerada, mas o runner Linux não compilou, assinou nem testou iOS. Nenhum AAB, build de produção ou deploy foi feito.
- Não foram provisionados Supabase, serviços de nuvem, migrations, credenciais de serviço ou integrações de pagamento.

## Falta

- Fechar D-002 a D-007: seleção por proximidade, transferência entre centrais, preço/reconfirmação, reserva de estoque e horários, Pix e escopo móvel do painel do proprietário.
- Revisar e aprovar D-010: empresas, vínculos de usuários, papéis, RLS e testes negativos de isolamento, antes de migrations.
- Definir D-011: provedor, ambientes e hospedagem antes de provisionar qualquer serviço.
- Com o arquiteto sênior, definir IDs de produção, variantes por empresa, identidade visual, assinatura, compilação iOS em macOS e publicação.

## Próximo passo

Revisar o handoff, a matriz de acesso e os shells com Evandro e o arquiteto sênior. Só depois fechar as decisões pendentes e começar integrações e migrations versionadas, mantendo chaves privilegiadas fora do repositório e dos apps.
