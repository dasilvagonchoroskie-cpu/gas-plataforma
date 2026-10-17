# Edge Functions

Funções do servidor (Deno). Todas conferem quem chamou por dentro (por isso
`verify_jwt` fica desligado), validam a entrada e devolvem só o necessário.
Segredos ficam no Vault ou nos segredos do Supabase; `service_role` nunca vai
para os apps nem para o repositório.

| Função | Quem chama | O que faz |
|---|---|---|
| `cadastro` | App do cliente (visitante) | Cria a conta já confirmada |
| `admin-usuarios` | Dono (Super Central) | Cria operador/administrador, muda papel, desativa, senha nova |
| `endereco` | Apps logados | CEP (ViaCEP → BrasilAPI), localização no mapa e endereço do GPS (Nominatim → Photon → BrasilAPI), conferindo a rua e a cidade |
| `excluir-conta` | Cliente | Anonimiza pelo banco e apaga ficha, endereços, aparelhos, fotos e o login |
| `notificar` | Banco (gatilho, com segredo) | Push do Firebase a cada evento do pedido; lê a chave do Vault |
| `configurar-notificacoes` | Dono (Super Central) | Recebe a chave do Firebase, confere com o Google e guarda no Vault; envia aviso de teste |
| `assinatura-android` | Esteira do GitHub (token OIDC) | Entrega a chave de assinatura dos APKs só ao build oficial |

Publicação: pelas ferramentas do Supabase (MCP) no projeto de desenvolvimento;
na produção, na fase prevista na arquitetura.
