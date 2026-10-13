# Preparação do backend Supabase

O Supabase é o backend de referência no desenho atual, mas ainda não há projeto, credencial, configuração local ou migration neste repositório. Este diretório documenta a preparação; não representa conexão com produção.

## Componentes previstos

- Postgres como fonte de verdade para dados transacionais.
- Supabase Auth para autenticação.
- RLS como limite obrigatório de autorização por empresa, usuário e central.
- Storage privado para comprovantes e arquivos que não sejam públicos.
- Realtime apenas para eventos que o usuário tem autorização para receber.
- Edge Functions para operações privilegiadas que não devam ser executadas diretamente pelo cliente.

## Antes de conectar

1. Aprovar o modelo de empresas, perfis, associações de usuários, papéis e centrais.
2. Aprovar a matriz de permissões e cenários de teste de isolamento.
3. Escolher contas, região e planos para desenvolvimento/homologação/produção, verificando custo, backup e requisitos de dados.
4. Configurar segredos por ambiente no provedor; nunca versionar chaves.
5. Usar migrations versionadas e dados sintéticos nos testes.

Firestore e Render não foram selecionados como componentes adicionais. Uma eventual mudança de backend ou hospedagem precisa de decisão arquitetural registrada para manter uma fonte de verdade e evitar integrações duplicadas.
