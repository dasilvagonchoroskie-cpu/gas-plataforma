# Progresso

**Atualizado:** 2026-10-13

## Feito

- Criado o repositório privado `gas-plataforma` na conta GitHub `dasilvagonchoroskie-cpu`.
- Registradas as regras do trabalho em `CLAUDE.md`.
- Criadas a arquitetura-base e a lista de decisões em aberto.
- Aprovado o modelo multi-tenant white-label: várias empresas na plataforma compartilhada, com isolamento obrigatório por empresa.
- Definidos APKs Android dedicados por empresa para desenvolvimento e testes; em produção, Android será publicado em AAB na Play Store e iOS pela App Store, usando a mesma base de código.
- Criado o pacote Dart inicial `packages/nucleo` com modelo de configuração pública de marca da empresa, validação de campos e conversão JSON; oito testes cobrem normalização, serialização e rejeição de dados inválidos.
- Preparada a proposta de handoff e a matriz de acesso em `docs/IMPLEMENTACAO_E_HANDOFF.md` e `docs/MATRIZ_ACESSO_PROPOSTA.md`; ambas aguardam revisão e aprovação e não autorizam migrations.
- Criado `packages/design_system` com tema Material 3, navegação adaptável à largura e estados explícitos de módulos ainda não integrados.
- Criados shells Flutter separados para as três superfícies: `apps/cliente` (Início/Pedidos/Perfil), `apps/painel_proprietario` (administração do próprio tenant) e `apps/painel_central` (operação da central atribuída). Os shells não exibem dados fictícios nem concedem acesso; incluem testes de widget.
- Os dois painéis usam a casca responsiva compartilhada. A modelagem multi-tenant proposta continua pendente de aprovação; a identidade de empresa embutida nunca substitui autorização do servidor/RLS.
- Os shells e o design system estão registrados em `main` (commits `d44b077662b93fce30bd0f1b8ea5891fb37a42e6` e correção de formatação `88937d0f8806e2386cb422da58aa5f4aea3c5404`). O CI passou no [run 38455600126](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/actions/runs/38455600126), commit `88937d0f8806e2386cb422da58aa5f4aea3c5404`: Flutter 3.47.7; resolução de dependências, formatação, `flutter analyze --fatal-infos` e 17 testes de widget/unidade nos três apps e pacotes compartilhados.
- Geradas e versionadas as plataformas iniciais: Android e iOS para `apps/cliente`, Web para `apps/painel_proprietario` e `apps/painel_central`. São scaffolds Flutter, com IDs `com.example.*` e recursos genéricos provisórios; não são configurações de produção.
- A [execução 38461272949](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/actions/runs/38461272949), commit `c2b617c926839ef2f273a642d39937f0b7775270`, concluiu com sucesso: dependências, formatação, análise estática e testes; APK Android de depuração para `android-arm64`; builds Web de release dos dois painéis; upload do artefato `plataformas-e-builds-de-teste` com sete dias de retenção (expira em 2026-10-20 às 20:24 UTC). Os builds estão apenas no artefato de CI, não no Git nem publicados.
- O runner Linux não compilou nem assinou iOS; apenas gerou seus arquivos de projeto. Também não foi feito build de release/AAB, configuração de assinatura de produção ou deploy Web.
- Adicionado `.gitignore` para caches e saídas locais/efêmeras de Flutter, Gradle e Xcode, arquivos locais de SDK e configuração de ambiente.
- Nenhum repositório antigo foi acessado ou alterado.
- Nenhuma migration, projeto Supabase, credencial de serviço ou integração de pagamento foi criado. `supabase/` contém apenas guias preparatórios.

## Falta

- Gerar/versionar `pubspec.lock` dos apps quando a política de dependências for definida; ainda não faz parte do scaffolding registrado.
- Substituir IDs, ícones e imagens genéricos somente após revisão do arquiteto sênior; definir variantes por empresa, identificadores finais, assinatura segura e publicação.
- Fechar as regras de proximidade, transferência entre centrais, preço, reserva de estoque/horário e Pix.
- Detalhar e aprovar D-010 (empresas, vínculos, papéis, políticas RLS e testes de isolamento) e D-011 (provedor, ambientes e hospedagem) antes de criar migrations ou integrações de negócio.
- Definir se o painel do proprietário será apenas Web responsivo ou também terá app móvel próprio.

## Próximo passo

Revisar o handoff, a matriz de acesso e os scaffolds com Evandro e o arquiteto sênior; fechar D-002 a D-007, D-010 e D-011. Só então criar migrations e testes de RLS, mantendo Supabase sem provisionamento e sem qualquer chave privilegiada no repositório.
