# Decisões do projeto

`docs/ARQUITETURA.md` é a fonte principal. Se houver diferença, vale a arquitetura aprovada mais recente por Evandro.

## Decisões fechadas

- Uma única revenda de gás e água (não é marketplace). Piloto em Goiatuba.
- O dono controla todas as centrais e pode abrir **quantas quiser, em qualquer cidade**, pelo painel. Centrais são dados no banco, nunca código.
- Flutter para o app do cliente (Android/iOS) e um painel único para dono e central (web e Android).
- Supabase é o backend único; Firebase Cloud Messaging serve somente para notificações push.
- Permissões aplicadas no banco com RLS; `service_role` nunca vai para os apps.
- Dinheiro em centavos inteiros; datas em UTC no banco e exibidas no horário de Brasília.
- Mudanças de banco só por migrations versionadas. Produção nunca é alterada manualmente.

## Decisões de 16/10/2026 (pedido do Evandro)

- **Central mais próxima:** o pedido cai na central ativa mais próxima do ponto do endereço do cliente no mapa. Não existe mais "escolher a cidade".
- **Faixas de entrega por distância** (`faixas_entrega`) substituem as áreas por bairro: cada central define "até X km, taxa Y". A maior faixa é o alcance; fora dele a central não atende.
- **Transferência entre centrais:** a central que não tem a mercadoria passa o pedido para outra central ativa. O preço combinado com o cliente não muda, o pedido volta para "novo" na central nova e o cliente é avisado. Limite de 5 transferências por pedido.
- **Número do pedido único da revenda** (a partir de 1001), para não repetir quando o pedido muda de central.
- **Entregadores** ficam numa tabela própria da central (nome e telefone), sem precisar de login; o app do entregador continua fora do piloto.
- **Cadastro do cliente** feito pela Edge Function `cadastro`, que cria a conta já confirmada (o e-mail gratuito do Supabase tem limite baixo). A recuperação de senha por e-mail depende de configurar um SMTP próprio; até lá, o dono cria senha nova pelo painel.
- **Mapas e endereços sem chave paga:** OpenStreetMap no app, ViaCEP e Nominatim pela Edge Function `endereco`.
- **Segredos do servidor no Vault** do Supabase (`notificar_url`, `notificar_segredo`, `android_chave_*`), lidos só pelas Edge Functions pela função `segredo_do_servidor` (restrita à `service_role`).
- **Assinatura dos APKs sem segredo no GitHub:** a chave da revenda fica no Vault; a Edge Function `assinatura-android` só a entrega ao build oficial (token OIDC do GitHub, ramo `main`, fluxo `validacao.yml`). Cópia da chave e senha entregues ao Evandro para guardar.
- **Fotos dos produtos:** só o dono envia ou troca; não há exclusão pelo app (menor privilégio).
- **Funções que os logados podem chamar** são as RPC de negócio, que conferem quem chamou por dentro; o visitante (anon) não executa nenhuma função.
- Aviso do Supabase sobre `pg_net` no esquema `public` é só cosmético (nenhum objeto dele fica em `public`); será ajustado na criação da produção.

## Decisões de 16/10/2026 (tarde, pedido do Evandro)

- O painel do dono se chama **Super Central** (o dono "toma conta de todas as lojas").
- **Ficha de cadastro obrigatória** para todo cliente antes do primeiro pedido (modelo de ficha de crediário de loja). Enquanto não é aprovada, o cliente já pode pedir pagando na entrega.
- **Quem aprova:** o dono. Ele pode liberar, nas configurações da seção Clientes, que as centrais aprovem as fichas da região delas, com um **limite máximo** opcional que a central pode dar.
- **Crediário (fiado) com limite:** limite livre = limite − o que deve − pedidos fiado ainda não entregues. A compra entra na conta quando o pedido é entregue. Dono e centrais registram pagamentos; ajustes manuais só o dono, com motivo (vai para a auditoria).
- **LGPD:** CPF, RG, renda e fotos ficam só com o cliente, o dono e a central que analisa (quando liberado). Fotos num bucket privado, abertas por link temporário. A auditoria não copia CPF. O cliente com valor em aberto não exclui a conta; ao excluir, a ficha e as fotos são apagadas.
- **Exclusão de dados pela Edge Function:** como a tela de confirmação de comandos de exclusão não abre para o Evandro (nem no celular nem pela web), as funções do banco não apagam linhas; quem apaga ficha, endereços, aparelhos e fotos na exclusão de conta é a Edge Function `excluir-conta`, com a chave do servidor. Aparelhos inválidos continuam sendo removidos pela função `notificar`.
