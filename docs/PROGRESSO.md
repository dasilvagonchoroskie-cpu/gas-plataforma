# Progresso

**Atualizado:** 2026-10-13

## Feito

- Criado o repositório privado `gas-plataforma`; nenhum repositório antigo foi acessado ou alterado.
- Registradas a arquitetura multi-tenant white-label e as decisões já aprovadas. A matriz de acesso e o handoff continuam como propostas para revisão do arquiteto, não como autorização para criar migrations.
- Criado `packages/nucleo` com modelo de configuração pública de marca e validação, e `packages/design_system` com tema Material 3, navegação responsiva e estados seguros de preparação.
- Criados três shells Flutter: `apps/cliente`, `apps/painel_proprietario` e `apps/painel_central`, sem autenticação, autorização, backend ou dados de negócio simulados.
- Geradas e versionadas as plataformas Android/iOS do app do cliente e Web dos dois painéis. IDs `com.example.*` e recursos visuais genéricos são placeholders, não configurações de produção.
- Adicionados ao Git os cinco `pubspec.lock` (três apps e dois pacotes privados) pelo workflow `Fixar dependências Flutter`, após Flutter 3.47.7 resolver dependências, formatar, analisar e passar os testes. A execução [38464776457](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/actions/runs/38464776457) foi bem-sucedida; os lockfiles foram registrados no commit `fbced56000cb320f33f43c85f43c1d2f4870872a`.
- A execução [38461272949](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/actions/runs/38461272949) também validou formatação, análise e testes; compilou um APK Android debug `arm64` e builds Web dos dois painéis. O artefato `plataformas-e-builds-de-teste` expira em 2026-10-20 às 20:24 UTC. Os binários não foram adicionados ao Git, publicados ou implantados. O [guia de builds](GUIA_BUILDS_TESTE.md) explica como inspecionar o artefato.
- A pasta iOS foi gerada, mas o runner Linux não compilou, assinou nem testou iOS. Nenhum AAB, build de produção ou deploy foi feito.
- Não foram provisionados Supabase, serviços de nuvem, migrations, credenciais de serviço ou integrações de pagamento.

## Falta

- Fechar D-002 a D-007: seleção por proximidade, transferência entre centrais, preço/reconfirmação, reserva de estoque e horários, Pix e escopo móvel do painel do proprietário.
- Revisar e aprovar D-010: empresas, vínculos de usuários, papéis, RLS e testes negativos de isolamento, antes de migrations.
- Definir D-011: provedor, ambientes e hospedagem antes de provisionar qualquer serviço.
- Com o arquiteto sênior, definir IDs de produção, variantes por empresa, identidade visual, assinatura, compilação iOS em macOS e publicação.

## Próximo passo

Revisar o handoff, a matriz de acesso e os shells com Evandro e o arquiteto sênior. Só depois fechar as decisões pendentes e começar integrações e migrations versionadas, mantendo chaves privilegiadas fora do repositório e dos apps.
