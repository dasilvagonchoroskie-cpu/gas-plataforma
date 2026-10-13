# Arquitetura — pedidos de gás e água

**Estado:** a decisão de produto multi-tenant white-label foi aprovada. A modelagem detalhada de isolamento e algumas regras operacionais seguem em revisão. Este documento não autoriza ainda a implementação do banco ou dos aplicativos; as decisões pendentes em `DECISOES.md` precisam ser aprovadas antes das fases que dependem delas.

## 1. Objetivo e piloto

Construir um produto seguro para um único revendedor de gás de cozinha e água mineral, começando pelo piloto em Goiatuba e preparado para atender Goiatuba, Itumbiara e Bom Jesus de Goiás. O proprietário administra o negócio; as centrais atendem pedidos e organizam as entregas.

Pode haver mais de uma central no mesmo município. A base de código do aplicativo do cliente é compartilhada entre empresas, mas cada empresa terá sua variante dedicada no Android. O cliente cria conta com e-mail e senha ou Google, informa nome e telefone, registra endereços e pode autorizar o uso da localização precisa para encontrar uma central próxima. A permissão de GPS não substitui o preenchimento ou a confirmação do endereço; deve existir alternativa manual.

A cidade e a central não podem ficar fixas no código. São dados administrados pelo proprietário. O município restringe quais centrais podem atender ou receber um pedido encaminhado.

## 2. Escopo informado

### Piloto

- Aplicativo do cliente para Android e iOS: cadastro/login, perfil, cidade/endereço, catálogo, carrinho, escolha de data e horário, pedido, acompanhamento, histórico e repetição do último pedido. No Android, gerar APK dedicado por empresa a partir da mesma base; distribuição direta fora das lojas. O processo de distribuição do iOS ainda precisa ser definido.
- Painel para o proprietário: administrar centrais, operadores, produtos, preços e visão geral.
- Painel das centrais: pedidos, horários/capacidade, estoque, entregadores e registro operacional.
- Notificações push de mudanças de status.
- Relatórios operacionais e de vendas, conforme as permissões aprovadas.

A stack proposta é Flutter/Dart, com Flutter Web para o painel, Flutter para o app, Supabase (Postgres, Auth, RLS, Realtime, Storage e Edge Functions), Firebase Cloud Messaging apenas para push, hospedagem web estática e GitHub Actions. Provedores, planos e limites precisam ser verificados antes da contratação e configuração.

### Fora do piloto, mas com espaço para integração futura

- App do entregador.
- Integração com gateway de pagamento e confirmação automática de Pix por webhook.
- Lembrete automático de recompra.
- Novas verticais comerciais reutilizando componentes aprovados, sem adicionar funções de outros ramos ao piloto de gás e água.

## 3. Regras do negócio registradas

### Centrais e encaminhamento

1. O aplicativo procura uma central elegível na mesma cidade/município do endereço do cliente e apresenta ou atribui a central mais próxima conforme uma regra de proximidade ainda a definir.
2. Se a central inicialmente responsável não tiver o produto, um operador autorizado pode encaminhar o pedido a outra central **do mesmo município**, nunca a uma cidade vizinha.
3. A transferência deve registrar central de origem, central de destino, motivo, responsável e horário. A central de destino passa a processar o pedido conforme uma transição permitida.
4. A central escolhida, os preços e as disponibilidades são validados no servidor. Não se aceita uma central arbitrária informada pelo aplicativo.
5. Se o preço mudar após o encaminhamento, o sistema não deve alterar silenciosamente o total que o cliente aceitou. A regra de preço e eventual confirmação do cliente ainda precisam ser decididas.
6. Centrais, endereços e áreas de entrega devem ter localização e limites de atendimento configuráveis, sem nomes de cidades escritos como regras no aplicativo.

### Contas, acesso e dados

- O cliente pode entrar com e-mail/senha ou Google; nome e telefone são completados no perfil.
- O acesso à localização é solicitado com permissão e explicado ao cliente; quem não autorizar pode informar o endereço manualmente.
- O cliente vê e administra apenas seu perfil, endereços e pedidos permitidos.
- Operadores veem apenas os dados operacionais das centrais que lhes foram atribuídas.
- O proprietário administra todas as centrais e tem a visão de gestão autorizada.
- Criar operadores, atribuir papéis e executar operações privilegiadas ocorre no servidor, nunca usando a chave `service_role` nos apps.
- Acesso por tela não é uma barreira de segurança: permissões precisam ser verificadas no banco e nas funções do servidor.

### Pedidos, estoque e horários

- Preços, subtotal, taxa de entrega, total, central responsável, vagas e disponibilidade são calculados/validados no servidor.
- Valores monetários são inteiros em centavos. Horários de operação são interpretados em `America/Sao_Paulo`; instantes gravados são tratados com fuso horário.
- Criação do pedido, confirmação de vaga e movimentos críticos precisam ser transacionais e protegidos contra pedidos concorrentes.
- As regras de reserva de estoque, liberação após cancelamento e baixa na entrega ainda precisam ser aprovadas. O estoque não pode ficar negativo nem ser vendido em duplicidade.
- Mudanças de status seguem uma máquina de estados permitida e deixam histórico com autor e data.

### Pagamentos

- Dinheiro: pago na entrega.
- Cartão de débito/crédito: pago ao entregador na entrega, usando a maquininha. A plataforma não coleta nem armazena dados do cartão.
- Pix no piloto: o aplicativo pode exibir QR Code e/ou código para copiar e colar e permitir anexar o comprovante ao pedido. O arquivo deve ficar em armazenamento privado, com acesso restrito e validação de tipo/tamanho.
- Enviar uma imagem de comprovante **não confirma que o dinheiro foi recebido**. Até haver integração com gateway/banco, uma pessoa autorizada da central precisa conferir o recebimento e registrar a confirmação. Um comprovante não pode, sozinho, liberar um pedido como pago.
- O estado do pagamento deve ser separado do estado da entrega. Chave Pix compartilhada ou por central, valor no QR Code, prazos, rejeição/reenvio de comprovante e conciliação manual ainda precisam de decisão.
- Fiado não será cobrado nem controlado como dívida pela plataforma no escopo descrito. As partes resolvem isso fora do sistema.
- A arquitetura deve permitir adicionar um gateway depois por uma integração isolada, com confirmações assinadas, idempotência, validação de webhook e reconciliação. Isso não autoriza incluir o gateway no piloto.

## 4. Arquitetura técnica proposta

- Um backend lógico com Postgres, Auth, Realtime, Storage e Edge Functions no Supabase; sem microsserviços no piloto.
- Um monorepo: app do cliente, painel web e pacote Dart compartilhado para modelos/regras que realmente possam ser compartilhados.
- Banco versionado em migrations; dados de demonstração em seed separado de dados reais.
- RLS em todas as tabelas e arquivos privados. Funções privilegiadas com permissões mínimas, `search_path` fixo, checagem de identidade/papel e testes.
- Supabase Realtime para eventos autorizados de pedidos; notificações push com conteúdo mínimo, sem endereço ou outros dados pessoais no texto da notificação.
- Segredos apenas nos locais de segredo do provedor/CI; nenhuma chave privilegiada embutida nos apps ou no repositório.
- Backups e exportação independente com procedimento de restauração testado antes do piloto.

## 5. Reutilização: multi-tenant white-label

**Decisão aprovada:** será uma plataforma compartilhada por várias empresas (multi-tenant), com personalização white-label e isolamento rigoroso entre empresas. Uma empresa equivale ao tenant raiz; suas centrais, operadores, clientes, pedidos, arquivos e configurações pertencem a ela.

Princípios obrigatórios antes de qualquer migration:

- A tabela `empresas` representa cada negócio/tenant. Toda informação operacional deve pertencer a uma empresa, diretamente por `empresa_id` ou por relação verificável no banco.
- RLS deve restringir o acesso primeiro à empresa e depois ao papel e à central. O proprietário administra somente sua própria empresa e suas centrais; não existe acesso cruzado entre empresas no produto.
- Identidade de login é separada da associação a uma empresa. A mesma pessoa poderá eventualmente participar de mais de uma empresa sem misturar dados; papéis e vínculo devem ser validados no servidor.
- Testes automatizados devem provar que um usuário de uma empresa não lê, altera, assina ou recebe eventos/arquivos de outra empresa. Essa validação cobre banco, Storage, Realtime, funções de servidor e notificações.
- Personalização por empresa deve ser configurável (por exemplo: nome, marca, cores, logo e contatos) e nunca depender de cidades ou nomes de clientes escritos no código.
- O núcleo reutilizável será separado das regras específicas de cada ramo. O piloto implementa apenas gás e água; outra atividade exige módulo próprio, análise de segurança e aprovação de escopo.
- O dono de cada negócio é administrador apenas do seu tenant. A existência de um administrador global da plataforma está fora do escopo atual.

**Android — distribuição aprovada:** gerar um APK dedicado para cada empresa usando Flavors/variantes Flutter a partir da mesma base de código. Nome do app, ícone, cores, URL pública do logo e identificador de configuração da empresa poderão ser definidos no build a partir da configuração da empresa no banco. O pipeline só pode consumir campos públicos permitidos; APKs são inspecionáveis e nunca podem conter segredos. O identificador da empresa no APK serve para selecionar a configuração, não para autorizar acesso: login, associação à empresa e RLS no backend são a barreira de segurança. A distribuição será direta, fora das lojas.

Assinatura dos APKs, identificador exclusivo por empresa, local seguro de hospedagem e processo de atualização ainda precisam ser definidos antes de distribuir builds reais. Se uma marca mudar depois da compilação, decidir se é necessária uma nova versão ou se o logo público pode ser atualizado em tempo de execução.

**iOS — pendente:** APK é formato Android. A estratégia para iPhone precisa ser definida separadamente; o pedido original inclui Android e iOS, mas a decisão de APK direto cobre somente Android.

## 6. Fases propostas

0. Aprovar o desenho detalhado de isolamento multi-tenant, a distribuição white-label, os ambientes e a documentação; preparar integração contínua.
1. Banco, migrations, RLS, funções transacionais, seed e testes de isolamento.
2. Painel do proprietário.
3. Painel das centrais e transferência de pedidos.
4. Aplicativo do cliente.
5. Push e relatórios.
6. Testes finais, backup/restauração, privacidade, exclusão de conta e preparação das lojas.
7. Piloto controlado em Goiatuba, mantendo o atendimento atual em paralelo no começo.

A fase e seu aceite devem ser definidos antes de cada implementação. Custos, requisitos de publicação das lojas, políticas e limites de fornecedores devem ser conferidos novamente perto da contratação/lançamento.
