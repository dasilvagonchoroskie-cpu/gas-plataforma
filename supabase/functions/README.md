# Edge Functions

Nenhuma função de backend foi criada ainda. Use este local somente para operações que precisem de validação confiável no servidor; não replique regras críticas em funções diferentes sem necessidade.

Toda função futura deve validar o JWT, resolver permissões no servidor, validar entrada e saída, limitar dados retornados, evitar exposição de informações pessoais e registrar auditoria sem segredos. Operações privilegiadas devem usar a menor permissão possível, tratar repetição/idempotência quando aplicável e manter `service_role` exclusivamente no ambiente seguro do servidor.

Operações de pedido, reserva e pagamento dependem das decisões D-002 a D-005; não as implementar por antecipação.
