# Testes de segurança do backend

Ainda não há testes de banco ou funções. Eles pertencem à Fase 1 e serão preparados com dados sintéticos em desenvolvimento, sem contas ou dados reais.

A cobertura deverá provar acesso permitido e negado conforme os papéis definidos na arquitetura. Casos mínimos de isolamento: operador da central A não consegue consultar nem alterar dados da central B; cliente não consegue consultar nem alterar dados de outro cliente. Os testes devem exercitar as permissões reais do banco (RLS), não apenas filtros de interface.

A estratégia e os comandos de execução serão definidos quando o projeto gratuito de desenvolvimento estiver criado e a Fase 1 for autorizada. Não usar credenciais nem dados de produção.
