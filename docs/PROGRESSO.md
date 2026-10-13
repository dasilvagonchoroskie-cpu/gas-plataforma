# Progresso

**Atualizado:** 2026-10-13

## Feito

- Criado o repositório privado `gas-plataforma` na conta GitHub `dasilvagonchoroskie-cpu`.
- Registradas as regras do trabalho em `CLAUDE.md`.
- Criadas a arquitetura-base e a lista de decisões em aberto.
- Aprovado o modelo multi-tenant white-label: várias empresas na plataforma compartilhada, com isolamento obrigatório por empresa.
- Definidos APKs Android dedicados por empresa para desenvolvimento e testes; em produção, Android será publicado em AAB na Play Store e iOS pela App Store, usando a mesma base de código.
- Criado o pacote Dart inicial `packages/nucleo` com o modelo de configuração pública de marca da empresa, validação de campos e conversão JSON. A documentação esclarece que o identificador/configuração embutidos no app não autorizam acesso; o backend e as políticas RLS devem impor o isolamento.
- Adicionados testes para normalização, serialização e rejeição de dados inválidos (oito testes no pacote).
- CI do GitHub Actions validado com sucesso no [run 38438819586](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/actions/runs/38438819586), commit `93079baf12dc149a7ff131bba02d6e8a2ce91c3f`: encontrou `packages/nucleo/pubspec.yaml`, instalou Flutter 3.47.7 e passou obtenção de dependências, formatação, `flutter analyze --fatal-infos` e `flutter test`.
- CI repetido e aprovado no [run 38440271959](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/actions/runs/38440271959), commit `770857ea3d75e1e7b151c14c90be2701d1557354`, após adicionar a estrutura preparatória dos apps; análise e testes do pacote continuaram passando.
- Nenhum repositório antigo foi acessado ou alterado.
- Nenhuma migration, projeto Supabase, credencial de serviço ou integração de pagamento foi criado. Os `README.md` em `supabase/` apenas preparam a estrutura e explicitam os critérios anteriores à conexão.
- Criado `docs/IMPLEMENTACAO_E_HANDOFF.md` com arquitetura de referência, proposta de isolamento multi-tenant, ciclo de ambientes, gates de segurança e checklist para o arquiteto sênior.
- Criados guias preparatórios em `apps/` e `supabase/`; não foi gerado template incompleto de app nem configuração que sugira conexão já existente.
- Registradas como pendentes D-010 (modelo detalhado de tenant/RLS) e D-011 (provedor, ambientes e hospedagem) em `docs/DECISOES.md`.

## Falta

- Fechar as regras de proximidade, transferência entre centrais, preço, reserva de estoque/horário e Pix.
- Preparar variantes por empresa para Android/iOS e definir identificadores e configurações necessárias.
- Deixar assinatura e publicação para a etapa final, com o arquiteto sênior indicado pelo proprietário; nenhuma chave/certificado deve entrar no repositório ou no binário.
- Detalhar e aprovar o modelo de empresas, vínculos de usuários, políticas RLS e testes de isolamento antes da primeira migration.
- Definir se o painel do proprietário será apenas web responsivo ou também app móvel.

## Próximo passo

Revisar este handoff com Evandro e o arquiteto sênior; fechar D-002 a D-007, D-010 e D-011. Só então criar migrations e testes de RLS, mantendo Supabase ainda sem provisionamento e sem qualquer chave privilegiada no repositório.
