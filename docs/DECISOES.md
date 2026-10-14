# Decisões do projeto

`docs/ARQUITETURA.md` é a fonte principal. Se houver diferença, vale a arquitetura aprovada mais recente por Evandro.

## Decisões fechadas

- Uma revenda atende Goiatuba, Itumbiara e Bom Jesus de Goiás; no piloto, somente Goiatuba fica ativa.
- O dono controla todas as centrais. Municípios e centrais são dados configuráveis, não nomes fixos no código.
- Flutter para o app de cliente Android/iOS e painel web único para dono e central.
- Supabase é o backend único; Firebase Cloud Messaging serve somente para notificações push.
- Permissões são aplicadas no banco com RLS; `service_role` nunca vai para os apps.
- Dinheiro é armazenado em centavos inteiros; datas ficam em UTC no banco.
- Mudanças de banco passam por migrations versionadas. Produção nunca é alterada manualmente.
- Seguir a ordem das fases de `docs/ARQUITETURA.md`; assinatura e publicação ficam para a etapa final.

## Estado atual

- Evandro informou que vinculou o Supabase ao GitHub. Ainda falta confirmar qual projeto está ligado e revisar as opções de implantação.
- A conexão deve apontar para o projeto gratuito de desenvolvimento, em organização separada. Não habilitar implantação automática em produção.
- Produção não existe e não deve ser criada nesta etapa.
- Nenhuma migration, função de negócio ou seed com dados de negócio foi criada. A Fase 1 ainda não começou.
