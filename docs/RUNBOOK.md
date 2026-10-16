# Runbook — operação e recuperação

Não contém nem deve receber senhas, tokens ou chaves secretas.

## 1. Ambientes

- **Desenvolvimento:** Supabase `cytxdxnansmzptzhnrfq` (conta da plataforma, plano gratuito). Dados só de teste.
- **Produção:** ainda não existe. Será criada no nome do dono (Supabase Pro), aplicando as mesmas migrations em ordem.
- Configuração pública dos apps: `config/ambiente_dev.json` (endereço e chave `anon`).

## 2. Esteira (GitHub Actions)

- Todo envio ao `main` roda **Verificações Flutter**: formatação automática, análise, testes; depois gera os três APKs assinados (cliente, Super Central e Central) e os dois painéis web.
- Relatórios em português: ramo `ci-relatorio` (Flutter) e `ci-relatorio-banco` (banco).
- Entregas: ramo `entregas` (`gas-agua-cliente.apk`, `gas-agua-super-central.apk`, `gas-agua-central.apk`, `painel-web-super-central.tar.gz`, `painel-web-central.tar.gz`, `SHA256SUMS.txt`, `LEIA-ME.txt`).

## 3. Chave de assinatura dos APKs

- Arquivo `gas-agua-revenda.jks`, apelido `revenda`. Cópia guardada pelo Evandro (arquivo e senha entregues em 16/10/2026) e no Vault do Supabase (`android_chave_base64`, `android_chave_senha`, `android_chave_apelido`).
- A Edge Function `assinatura-android` só entrega a chave ao build oficial (token OIDC do GitHub: repositório, ramo `main`, fluxo `validacao.yml`).
- **Perder a chave impede atualizar o app já instalado.** Na Google Play, ativar a "Assinatura de apps do Google Play" e usar esta chave como chave de upload.
- Se a chave vazar: gerar outra, trocar os três segredos no Vault e, na Play, pedir a troca da chave de upload.

## 4. Primeiro administrador

O primeiro dono não tem como ser criado pelo painel. Procedimento usado no desenvolvimento:

1. Criar a conta pela Edge Function `cadastro` (nasce como cliente).
2. Promover pelo SQL do projeto: `update public.perfis set papel = 'dono' where email = '<e-mail>';` (fica registrado na auditoria).
3. Os demais usuários (operadores e outros administradores) são criados pelo próprio dono no painel → Usuários.

## 5. Falha do app ou painel

1. Registrar horário, tela e mensagem visível; não colocar nome, telefone, endereço ou tokens em logs públicos.
2. Conferir os logs das Edge Functions e do banco no painel do Supabase.
3. Durante o piloto, manter o atendimento por WhatsApp em paralelo.
4. Nunca corrigir dados direto no banco de produção: corrigir por código, testes e migration.

## 6. Senha esquecida

Enquanto não houver SMTP próprio, o e-mail de recuperação é limitado. O dono entra no painel → Usuários → (pessoa) → "Criar senha nova" e passa a senha provisória.

## 7. Backups e restauração

- Antes do piloto: confirmar o backup diário do plano Pro, preparar exportação semanal fora do Supabase e testar a restauração num projeto separado.
- Nunca testar restauração sobre produção.

## 8. Troca de chaves

- Trocar credenciais só no painel oficial do provedor (Supabase, Firebase, Google Play) ou no Vault.
- Nunca enviar segredos por commit, print, log ou APK. A `service_role` fica só no servidor.

## 9. Banco fora do ar

- Usar o WhatsApp; não confirmar pedido, pagamento ou estoque sem o sistema.
- Não repetir operações sem confirmar o resultado (o pedido tem chave contra duplicação, mas confira).
- Ao voltar, conferir os pedidos recebidos fora do app.
