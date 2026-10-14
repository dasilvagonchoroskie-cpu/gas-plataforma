# Passagem — rascunhos da Fase 1

**Data:** 2026-10-14 17:18 -03  
**Estado:** arquivos escritos; não aplicar à integração do Supabase nem a qualquer banco do projeto.

## Limite obrigatório

Os rascunhos ficam em `docs/rascunhos/fase1/`. Não criar nem alterar arquivos em `supabase/`, não mexer no projeto ou na integração Supabase, não executar `supabase link` ou `db push`, não abrir pull request nem criar branch. O workflow manual monta outro projeto dentro de um diretório temporário do runner e copia os rascunhos para lá apenas para teste local.

## Decisões provisórias — confirmar

1. Catálogo e preços só podem ser consultados por usuário autenticado; sem acesso anônimo.
2. Cada operador pertence a uma única central.
3. Cliente vê somente os próprios endereços e pedidos. Operador vê pedidos somente da própria central, incluindo o endereço de entrega copiado no pedido. Dono vê tudo.
4. Cliente pode cancelar somente enquanto o pedido estiver no primeiro status (`novo`). Depois disso, só operador da central ou dono pode cancelar, com motivo.
5. Ao excluir uma conta, anonimizar dados pessoais e manter pedidos para relatórios, após confirmar os requisitos de retenção e privacidade.
6. Não haverá acesso administrativo de suporte na primeira versão.

## Decisão de entrega do painel

O `apps/painel` (dono e centrais) será entregue como painel Web e também como app para celular Android e iOS, reutilizando o mesmo código Flutter. Será publicado separadamente do app dos clientes. Essa decisão não autoriza gerar plataformas Flutter nem alterar os aplicativos nesta etapa.

## Arquivos escritos e estado de validação

- `docs/rascunhos/fase1/esquema_inicial.sql`: esquema, restrições, índices, RLS, helpers, triggers e view. **Escrito; não testado em banco do projeto.**
- `docs/rascunhos/fase1/testes_isolamento.sql`: testes pgTAP de isolamento, permissões e FKs compostas. **Escrito; não testado em banco do projeto.**
- `docs/rascunhos/fase1/seed_ficticio.sql`: fixtures com nomes, endereços, contatos e IDs claramente fictícios. **Escrito; não carregado em banco do projeto.**
- `.github/workflows/banco-teste.yml`: workflow exclusivamente manual, usando Supabase local em diretório temporário do runner. **Escrito; resultado pendente.**

As quatro funções de negócio `criar_pedido`, `janelas_disponiveis`, `mudar_status_pedido` e `criar_central` aparecem apenas como assinaturas e comentários no SQL; não há corpos, stubs executáveis nem lógica de negócio. `criar_pedido` deverá ler o preço de `precos_central` no servidor e nunca aceitar preço ou total do app.

## Pontos técnicos a confirmar na revisão

- `central_id` foi repetido em `itens_pedido` e `historico_status` para permitir FKs compostas que evitem misturar centrais. `motivo_cancelamento` foi incluído em `pedidos` para registrar a regra provisória de cancelamento.
- A FK composta de `pedidos.entregador_id` usa `operadores_central`, e um trigger exige papel `entregador`; confirmar se essa é a relação desejada para entregadores, já que a arquitetura não define uma tabela separada de vínculo de entregadores.
- `auditoria.registro_id` é polimórfico no modelo e não pode ter uma FK composta relacional única. Definir como o servidor assegurará que o alvo e `central_id` correspondem.
- `movimentos_estoque.tipo` não tem valores enumerados na arquitetura; permanece texto até a lista oficial ser decidida.
- A view `v_pedidos_com_itens` é uma projeção de leitura adicional, com `security_invoker = true`; confirmar se deve permanecer.
- As funções de negócio estão somente documentadas; regras de preço, capacidade, transições, auditoria, exclusão/anonimização e operações de estoque ainda exigem implementação e testes na Fase 1.

## Resultado do workflow

- **Tentativa 1:** execução local temporária falhou (4/10 testes passaram). A verificação de preço consultava privilégio SQL apesar da proteção ser feita pela política RLS; os cinco `throws_ok` esperavam que o texto descritivo fosse a mensagem exata do PostgreSQL. Execução: https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/actions/runs/38632504314
- **Correções preparadas:** o teste de preço agora tenta uma alteração como cliente e verifica que o valor permanece; os testes de FK passam a validar o SQLSTATE `23503` sem exigir texto variável do erro. Aguardando nova execução manual.

Qualquer sucesso será somente de um Supabase local e temporário no runner — não valida a integração nem altera o banco do projeto.
