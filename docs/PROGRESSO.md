# Progresso

**Atualizado:** 2026-10-13

## Feito

- Criado o repositório privado `gas-plataforma` na conta GitHub `dasilvagonchoroskie-cpu`.
- Registradas as regras do trabalho em `CLAUDE.md`.
- Criadas a arquitetura-base e a lista de decisões em aberto.
- Aprovado o modelo multi-tenant white-label: várias empresas na plataforma compartilhada, com isolamento obrigatório por empresa.
- Definidos APKs Android dedicados por empresa para desenvolvimento e testes; em produção, Android será publicado em AAB na Play Store e iOS pela App Store, usando a mesma base de código.
- Criado o pacote Dart inicial `packages/nucleo` com modelo de configuração pública de marca da empresa, validação de campos e conversão JSON; oito testes cobrem normalização, serialização e rejeição de dados inválidos.
- CI do GitHub Actions validado com sucesso no [run 38438819586](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/actions/runs/38438819586), commit `93079baf12dc149a7ff131bba02d6e8a2ce91c3f`, e repetido no [run 38440271959](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/actions/runs/38440271959), commit `770857ea3d75e1e7b151c14c90be2701d1557354`.
- Preparada a proposta de handoff e a matriz de acesso em `docs/IMPLEMENTACAO_E_HANDOFF.md` e `docs/MATRIZ_ACESSO_PROPOSTA.md`; ambas aguardam revisão e aprovação e não autorizam migrations.
- Criado `packages/design_system` com tema Material 3, navegação adaptável à largura e estados explícitos de módulos ainda não integrados.
- Criados shells Flutter separados para as três superfícies: `apps/cliente` (Início/Pedidos/Perfil), `apps/painel_proprietario` (administração do próprio tenant) e `apps/painel_central` (operação da central atribuída). Os shells não exibem dados fictícios nem concedem acesso; incluem testes de widget.
- Os dois painéis usam a casca responsiva compartilhada. A modelagem multi-tenant proposta continua pendente de aprovação; a identidade de empresa embutida nunca substitui autorização do servidor/RLS.
- A estrutura de shells/design system foi enviada no commit `8db79778e5281699d634d37ad92f3670a8280f89`. O CI passou no [run 38454655942](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/actions/runs/38454655942): Flutter 3.47.7 instalado; `flutter pub get`, formatação, `flutter analyze --fatal-infos` e `flutter test` aprovados para todos os pacotes e apps Flutter detectados.
- Nenhum repositório antigo foi acessado ou alterado.
- Nenhuma migration, projeto Supabase, credencial de serviço ou integração de pagamento foi criado. `supabase/` contém apenas guias preparatórios.

## Falta

- Gerar e validar os projetos de plataforma Android/iOS do app de cliente e Web dos painéis; ainda não há pastas nativas nem builds APK/AAB/web.
- Fechar as regras de proximidade, transferência entre centrais, preço, reserva de estoque/horário e Pix.
- Definir identificadores finais, variantes por empresa, ícones, assinatura e publicação com o arquiteto sênior.
- Detalhar e aprovar D-010 (empresas, vínculos, papéis, políticas RLS e testes de isolamento) e D-011 (provedor, ambientes e hospedagem) antes de criar migrations ou integrações de negócio.
- Definir se o painel do proprietário será apenas web responsivo ou também terá app móvel próprio.

## Próximo passo

Revisar este handoff com Evandro e o arquiteto sênior; fechar D-002 a D-007, D-010 e D-011. Só então criar migrations e testes de RLS, mantendo Supabase sem provisionamento e sem qualquer chave privilegiada no repositório.
