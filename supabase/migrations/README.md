# Migrations do banco

Ainda não há migrations nem projeto Supabase conectado. A criação do esquema, políticas RLS e funções RPC pertence à Fase 1 e não está autorizada nesta etapa de preparação.

Quando a Fase 1 for autorizada, cada mudança será pequena, revisada, numerada e versionada neste diretório. Todas as tabelas devem ter RLS habilitada; a aplicação não substitui a autorização no banco. Produção nunca será alterada manualmente: somente migrations revisadas e aprovadas poderão mudar o banco.

Os testes devem cobrir permissões concedidas e negadas, inclusive provar que um operador da central A não acessa dados da central B e que o cliente acessa apenas os próprios dados autorizados. Esquema e políticas detalhados devem seguir `docs/ARQUITETURA.md`.
