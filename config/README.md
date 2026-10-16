# Configuração dos apps

`ambiente_dev.json` tem só dados **públicos** do ambiente de desenvolvimento:
o endereço do servidor (Supabase) e a chave pública `anon`. Essa chave é feita
para ficar dentro dos apps; quem protege os dados são as regras do banco (RLS).

Nunca coloque aqui a chave `service_role`, senhas ou chaves de assinatura.

Os builds usam o arquivo assim:

    flutter build apk --dart-define-from-file=../../config/ambiente_dev.json

Para produção, crie `ambiente_producao.json` com o endereço e a chave `anon`
do projeto de produção (fase prevista na arquitetura).
