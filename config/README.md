# Configuração dos apps

`ambiente_dev.json` tem só dados **públicos** do ambiente de desenvolvimento:
o endereço do servidor (Supabase) e a chave pública `anon`. Essa chave é feita
para ficar dentro dos apps; quem protege os dados são as regras do banco (RLS).

Também ficam aqui os dados **públicos** do Firebase (`FIREBASE_*`), que
identificam os três apps no projeto de notificações. Vazios = notificações
desligadas, sem atrapalhar o resto. A chave secreta do Firebase nunca entra
aqui: o dono envia pela Super Central → Notificações e ela vai para o cofre
(Vault) do servidor.

Nome, frase, cores, ícone e logo da revenda ficam na pasta `marca/` (veja
`marca/LEIA-ME.md`).

Nunca coloque aqui a chave `service_role`, senhas ou chaves de assinatura.

Os builds usam o arquivo assim:

    flutter build apk --dart-define-from-file=../../config/ambiente_dev.json --dart-define-from-file=../../marca/marca.json

No painel, junte também o tipo do aplicativo (`--flavor supercentral
--dart-define=PAINEL=supercentral` ou `--flavor central --dart-define=PAINEL=central`).

Para produção, crie `ambiente_producao.json` com o endereço e a chave `anon`
do projeto de produção (fase prevista na arquitetura).
