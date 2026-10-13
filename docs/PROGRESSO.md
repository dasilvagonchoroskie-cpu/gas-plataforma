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
- CI do GitHub Actions validado com sucesso no [run 38438819586](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/actions/runs/38438819586), commit `93079baf12dc149a7ff131bba02d6e8a2ce91c3f`: encontrou `packages/nucleo/pubspec.yaml`, instalou Flutter 3.47.7 e concluiu com sucesso a etapa de análise e testes do pacote, incluindo obtenção de dependências, checagem de formatação, `flutter analyze --fatal-infos` e `flutter test`.
- Nenhum repositório antigo foi acessado ou alterado.
- Nenhuma migration, ambiente Supabase ou integração de pagamento foi criado.

## Falta

- Fechar as regras de proximidade, transferência entre centrais, preço, reserva de estoque/horário e Pix.
- Preparar variantes por empresa para Android/iOS e definir identificadores e configurações necessárias.
- Deixar assinatura e publicação para a etapa final, com o arquiteto sênior indicado pelo proprietário; nenhuma chave/certificado deve entrar no repositório ou no binário.
- Detalhar e aprovar o modelo de empresas, vínculos de usuários, políticas RLS e testes de isolamento antes da primeira migration.
- Definir se o painel do proprietário será apenas web responsivo ou também app móvel.

## Próximo passo

Revisar com Evandro as decisões pendentes D-002 a D-007 e D-009 de `docs/DECISOES.md` antes de iniciar fluxos de negócio ou migrations.
