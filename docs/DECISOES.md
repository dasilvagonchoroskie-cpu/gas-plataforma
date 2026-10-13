# Decisões do projeto

Este registro separa o que Evandro já definiu do que ainda precisa ser decidido. Uma sugestão da equipe não vira regra sem aprovação.

## Decisões confirmadas

- Trabalhar somente neste projeto novo; projetos/repositórios anteriores ficam intocados sem ordem explícita.
- Segurança, privacidade e qualidade profissional desde o início; nenhum segredo no código; mudanças do banco por migrations versionadas.
- App do cliente em Flutter/Dart para Android e iOS; painel web em Flutter; backend proposto em Supabase, ainda sujeito à validação de arquitetura e contas.
- No piloto, um revendedor opera várias centrais; podem existir duas ou mais no mesmo município.
- Atendimento e encaminhamento de um pedido ficam dentro do mesmo município.
- Cliente pode autenticar com Google ou e-mail/senha, informa telefone e endereço e pode permitir localização precisa, com alternativa de informar o endereço manualmente.
- Dinheiro e cartão na entrega; cartão processado na maquininha do entregador. Pix pode mostrar QR/código copia e cola e aceitar envio de comprovante; a imagem exige conferência humana até integração futura.
- Fiado fica fora da plataforma, sem controle de dívida.
- Uma integração com gateway de pagamento pode ser adicionada futuramente, sem fazer parte do piloto.
- **D-001 — Multi-tenant white-label:** várias empresas usarão uma plataforma compartilhada; os dados de cada empresa devem ficar isolados e a identidade visual deve ser configurável por empresa.
- O proprietário de cada negócio administra somente a própria empresa; não há administrador global entre empresas no escopo atual.
- Cada fase precisa de documentação, explicação em português, testes e aceite antes de seguir.

## Decisões pendentes antes do banco e do código de negócio

### D-002 — Como escolher a central mais próxima

Definir se proximidade será distância em linha reta, tempo/distância por rota ou área/bairro de atendimento configurada. A escolha deve ocorrer apenas entre centrais ativas que atendem o município e o endereço.

### D-003 — Transferência e preço

Definir quando a transferência é permitida (por exemplo, falta de estoque), se o destino precisa aceitar, como manter o preço já apresentado e quando pedir nova confirmação ao cliente.

### D-004 — Reserva de estoque e vaga

Definir o instante de reserva, o instante de baixa definitiva, a liberação em cancelamentos e a regra de capacidade de horários, sempre com transação concorrente segura.

### D-005 — Pix no piloto

Definir uma chave Pix da empresa ou uma chave por central; se o QR inclui valor e identificador do pedido; quem confere no banco; como aprovar/rejeitar comprovante; e quando o pedido pode avançar. O upload não é confirmação bancária.

### D-006 — Painel do proprietário

O documento inicial prevê Flutter Web. Confirmar se o proprietário usará esse painel adaptado para celular ou se também haverá um aplicativo móvel nativo separado.

### D-007 — Dados pessoais e exclusão de conta

Definir prazo de retenção de endereços, pedidos, comprovantes e registros financeiros e como cumprir uma solicitação de exclusão sem apagar registros cuja retenção seja necessária.

### D-008 — Marca e distribuição nas lojas

Definir se haverá um único aplicativo compartilhado com marca configurável após identificar a empresa ou uma listagem/aplicativo por empresa, reutilizando o mesmo código.

## Registro de alterações

- 2026-10-13 — Criado repositório privado e registrados os requisitos apresentados pelo proprietário; nenhuma implementação de aplicação ou banco iniciada.
- 2026-10-13 — Aprovada a arquitetura multi-tenant white-label; modelo de isolamento por empresa registrado, sem início de migrations ou código de produto.
