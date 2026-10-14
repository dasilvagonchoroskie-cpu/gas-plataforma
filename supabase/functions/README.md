# Edge Functions

Nenhuma Edge Function foi criada. As funções previstas na arquitetura, como tarefas de notificação, só serão implementadas na fase correspondente e após a Fase 1 preparar e proteger o banco.

Toda função futura deverá validar entradas no servidor, aplicar as permissões adequadas, limitar os dados retornados, proteger dados pessoais e tratar repetição de operações críticas. Segredos ficam somente nos ambientes seguros do servidor; `service_role` nunca entra em apps ou no repositório.

Não antecipar funções de pedidos, pagamentos ou outras fases. Seguir `docs/ARQUITETURA.md` e registrar mudanças como parte da etapa aprovada.
