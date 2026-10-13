# Matriz preliminar de acesso multi-tenant

**Estado: proposta para revisão do arquiteto e aprovação do proprietário. Não usar como autorização para criar migrations.**

Esta matriz traduz os requisitos atuais em um ponto de partida testável. As permissões devem ser implementadas no banco/servidor e testadas; ocultar telas ou filtrar consultas no app não é controle de segurança.

## Princípios

- O usuário autenticado é identificado por `auth.uid()`. `empresa_id`, `central_id`, papel e estado de associação são conferidos no servidor.
- `empresa_id` fornecido pelo cliente seleciona contexto visual; não concede permissão.
- Proprietários e operadores precisam de associação ativa. O operador precisa também estar atribuído à central permitida.
- Acesso de cliente deriva do próprio usuário e da relação com o pedido. Ser cliente não concede papel administrativo na empresa.
- Negação por padrão; cada operação de leitura e escrita recebe regra própria.
- Dados pessoais só aparecem quando necessários para a tarefa, com escopo e duração mínimos.

## Matriz proposta

| Recurso | Anônimo | Cliente autenticado | Proprietário | Operador de central | Servidor confiável |
|---|---|---|---|---|---|
| Identidade pública da empresa | Ler somente campos públicos de empresa ativa | Igual | Gerir somente o próprio tenant | Ler campos operacionais mínimos do próprio tenant | Validar e publicar configurações permitidas |
| Perfil pessoal | Sem acesso | Ler/alterar campos permitidos do próprio perfil | Ver apenas dados necessários à operação autorizada | Ver apenas dados necessários a pedidos da central atribuída | Validar campos e operações privilegiadas |
| Associação e papéis | Sem acesso | Consultar somente vínculo próprio, se necessário | Ver equipe do próprio tenant; mudanças de papel somente por fluxo protegido | Consultar apenas atribuição própria | Criar, suspender ou alterar vínculo após validar autorização |
| Centrais | Sem dados privados; localização pública somente se aprovada | Ler centrais elegíveis e dados públicos de atendimento | Gerir centrais do próprio tenant | Ler/operar somente centrais atribuídas | Validar município, cobertura e relações entre empresa e central |
| Catálogo e preços | Leitura pública apenas se produto aprovar navegação anônima | Ler catálogo ativo da empresa selecionada | Gerir catálogo/preços do próprio tenant | Ler catálogo da central; ajustes somente conforme papel aprovado | Calcular e validar preços e totais no servidor |
| Endereços de entrega | Sem acesso | Gerir somente os próprios | Sem consulta ampla por padrão; acesso operacional só quando necessário e auditado | Acessar endereço somente dos pedidos ativos atribuídos | Devolver dados mínimos ao fluxo autorizado |
| Pedidos | Sem acesso | Criar por operação validada; ler próprios; alterações/cancelamento só por transição permitida | Ver e administrar pedidos do próprio tenant conforme transições válidas | Ver pedidos da central atribuída e executar transições autorizadas | Validar tenant, central, preço, estado, estoque e idempotência |
| Estoque e capacidade | Sem acesso a registros internos | Ver disponibilidade calculada, nunca alterar estoque diretamente | Gerir estoque/capacidade do próprio tenant | Operar estoque/capacidade da central atribuída, se autorizado | Serializar e validar reservas e movimentos concorrentes |
| Comprovantes Pix | Sem acesso | Enviar somente para pedido próprio; sem poder marcar como pago | Conferir registros do próprio tenant conforme trilha de auditoria | Conferir somente quando explicitamente designado | Restringir upload/leitura e registrar decisão humana; upload não confirma pagamento |
| Relatórios | Sem acesso | Sem acesso | Ver dados agregados do próprio tenant, minimizando dados pessoais | Ver somente o escopo da central atribuída | Calcular no servidor e limitar campos/exportações |
| Tokens de push | Sem acesso | Registrar/remover somente token próprio | Sem acesso a tokens de outras pessoas | Sem acesso a tokens de outras pessoas | Enviar notificação mínima aos destinatários autorizados |
| Auditoria | Sem acesso | Sem acesso | Consultar eventos do próprio tenant dentro da necessidade de negócio | Consultar eventos da central atribuída quando autorizado | Inserir eventos íntegros, sem segredos e com dados pessoais minimizados |

As permissões exatas de alteração, cancelamento, acesso de suporte e retenção precisam ser ajustadas às decisões D-002 a D-007 e D-010. A matriz não presume que qualquer usuário do tenant possa ler todos os dados pessoais.

## Testes negativos obrigatórios

Criar duas empresas sintéticas (A e B), usuários com papéis diferentes e pelo menos duas centrais no mesmo tenant. Testar explicitamente:

1. Anônimo não lê perfil, endereço, pedido, comprovante, estoque interno nem relatório.
2. Cliente A não lê ou altera dados privados do cliente B; não acessa pedido de outro usuário apenas conhecendo seu ID.
3. Cliente não cria pedido em nome de tenant arbitrário e não altera total, preço, status, empresa ou central após a validação do servidor.
4. Proprietário A não lista, lê, altera, exclui, exporta nem recebe eventos de B.
5. Operador atribuído à central A1 não acessa central A2 sem atribuição, mesmo que ambas pertençam à mesma empresa.
6. Operador A não acessa qualquer central, arquivo, função, evento ou relatório de B.
7. Usuário suspenso ou associação inativa perde permissões operacionais; tokens ou contexto antigo não restauram acesso.
8. Não é possível alterar `empresa_id` de um registro próprio para atravessar o tenant, nem associar uma central de B a um registro de A.
9. Políticas de Storage impedem leitura, substituição e exclusão de comprovantes de outros usuários/tenants, mesmo com caminho conhecido.
10. Realtime, RPC e Edge Functions repetem a checagem de autorização do banco e não aceitam papel/tenant confiado apenas ao corpo da requisição.
11. Operações concorrentes não reservam a mesma unidade ou vaga duas vezes quando estoque/agendamento forem implementados.

## Decisões que precisam de confirmação

- Catálogo, identidade da empresa e centrais podem ser consultados sem login? Quais campos exatamente são públicos?
- Um mesmo usuário pode ser proprietário/operador de várias empresas? Como alterna o contexto sem misturar dados?
- Quem pode convidar/desativar operadores e atribuir centrais? Haverá aprovação do proprietário?
- Que dados do endereço aparecem para operador e proprietário, em que fase do pedido e por quanto tempo?
- Quais transições de pedido, cancelamento, Pix, retenção e exportação são permitidas?
- Haverá função de suporte da plataforma? O escopo atual não prevê administrador global; qualquer exceção exige decisão específica e trilha de auditoria.

A equipe deve converter as respostas em uma matriz final, ameaças/mitigações e testes automatizados antes da primeira migration.
