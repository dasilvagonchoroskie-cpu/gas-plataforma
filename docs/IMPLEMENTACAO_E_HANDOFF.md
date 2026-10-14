# Continuidade do projeto — Claude Code

Este arquivo registra o ponto de retomada. **A fonte completa e principal é `docs/ARQUITETURA.md`; leia-a inteira antes de implementar.** Não recomeçar o projeto nem substituir decisões aprovadas.

## Objetivo e modelo

A plataforma atende uma única revenda de gás e água, não é marketplace. Ela terá centrais em Goiatuba, Itumbiara e Bom Jesus de Goiás; no piloto, só Goiatuba fica ativa. O dono administra todas as centrais, e cada cliente usa o mesmo app e fica ligado à central da sua cidade.

O produto previsto é:

- App Flutter Android/iOS para clientes.
- Um painel Flutter Web para dono e operadores das centrais.
- Supabase como backend único; Firebase Cloud Messaging somente para notificações push.

Os papéis, tabelas, regras de acesso, pagamentos e funções do banco estão definidos em `docs/ARQUITETURA.md`. Usar RLS para proteger os dados; todo dado operacional pertence à central. Não fixar cidades no código.

## O que está pronto

- Arquitetura aprovada registrada em `docs/ARQUITETURA.md`.
- Regras de trabalho em `CLAUDE.md`.
- Esqueleto do app cliente e do painel unificado organizado por funcionalidades.
- Módulos de interface existentes do dono e da central preservados; as pastas antigas continuam no repositório como referência até a validação do painel unificado.
- Documentação de decisões e runbook em preparação.
- CI, análise, formatação e testes Flutter passaram no GitHub Actions. Os links estão em `docs/PROGRESSO.md`.

O painel unificado ainda é somente um esqueleto: não tem login, backend conectado nem fluxos de negócio. Não criar dados fictícios para parecer funcional.

## Estado do Supabase

Evandro informou que vinculou o Supabase ao GitHub. Ainda é necessário confirmar qual projeto e ambiente foram vinculados e revisar as opções de implantação. A conexão deve usar somente o projeto gratuito de desenvolvimento; não habilitar implantação automática em produção.

Não há migrations, funções de negócio ou seed com dados reais no repositório. Não existe ambiente de produção criado ou autorizado para uso.

## Próximo trabalho

1. Confirmar a integração informada e o projeto Supabase de desenvolvimento; se ainda não existir, criá-lo na organização separada prevista.
2. Aguardar autorização explícita de Evandro para começar a Fase 1.
3. Na Fase 1, seguir a arquitetura: migrations, RLS, RPCs, seed somente de teste e testes de permissões. Não avançar para os painéis nem para o app cliente antes das fases previstas.
4. Atualizar `docs/PROGRESSO.md` ao final de cada etapa e manter commits pequenos em português.

## Regras que não podem ser esquecidas

- Seguir a ordem da seção 11 de `docs/ARQUITETURA.md`; não inventar escopo.
- Nunca pedir nem registrar senhas ou `service_role`; nenhuma chave secreta vai para código ou repositório.
- Nunca alterar produção manualmente. Mudanças de banco são migrations versionadas e testadas.
- Evandro é iniciante: explicar cada passo em português simples e obter OK antes de alterar arquivos.
- Assinatura e publicação ficam para a etapa final indicada por Evandro.
