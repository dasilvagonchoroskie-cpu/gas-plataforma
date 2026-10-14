# Runbook — operação e recuperação

**Estado:** esqueleto inicial da Fase 0. Ainda não há projeto Supabase conectado. Não há ambiente de produção.

Este documento será completado e testado antes do piloto. Não contém nem deve receber senhas, tokens ou chaves secretas.

## 1. Identificação dos ambientes

- Desenvolvimento: Supabase gratuito, em organização separada, a ser criado por Evandro.
- Produção: ainda não existe; não provisionar nesta Fase 0.
- Responsáveis, links dos projetos e canais de contato serão registrados depois da criação/aprovação dos ambientes, sem incluir segredos.

## 2. Falha do app ou painel

1. Registrar horário, ambiente, tela e mensagem visível; não incluir nome, telefone, endereço ou tokens em logs públicos.
2. Conferir os alertas de execução do Supabase e GitHub Actions pelos acessos autorizados.
3. Manter o atendimento por WhatsApp em paralelo durante o piloto, conforme a arquitetura.
4. Não aplicar mudanças manuais no banco. Corrigir por código revisado, testes e migration autorizada.

## 3. Backups e restauração

- Antes do piloto: confirmar a política de backup diário do plano Supabase Pro, preparar exportação semanal fora do Supabase e testar a restauração em ambiente isolado.
- Registrar responsável, frequência, destino protegido, retenção e data do último teste de restauração quando esses itens forem configurados.
- Nunca testar restauração sobre produção.
- Procedimento detalhado e comandos serão adicionados após escolha/configuração do ambiente e testados antes de declarar prontos.

## 4. Troca de chaves

- Trocar credenciais somente no painel oficial do provedor e nos armazenamentos seguros correspondentes.
- Nunca enviar segredos por chat, commit, print, log ou APK.
- A chave `service_role` permanece exclusivamente no servidor/ambiente seguro; não entra em aplicativos.
- Registrar data, responsável e serviços afetados, sem registrar o valor da chave.

## 5. Indisponibilidade do banco

- Usar o atendimento atual por WhatsApp; não simular confirmação de pedido, pagamento ou estoque.
- Não repetir operações críticas sem confirmar o resultado, para evitar pedidos duplicados.
- Retomar a operação digital somente após confirmar a saúde do serviço e a reconciliação dos pedidos recebidos fora do app.

## 6. Informações pendentes

Os projetos, responsáveis, alertas, comandos de exportação e restauração, política de retenção e contatos serão preenchidos depois que os ambientes forem criados. Este runbook não autoriza provisionamento nem alterações de banco.
