# Guia de implementação e handoff técnico

**Estado:** preparação e proposta técnica para revisão do arquiteto sênior. Não representa aprovação de migrations, criação de recursos em nuvem ou contratação de fornecedores.

## 1. O que já está preparado

- Repositório privado e documentação inicial do produto.
- CI no GitHub Actions, com versões das Actions fixadas por commit e Flutter fixado em `.fvmrc`.
- `packages/nucleo` com configuração pública de marca e `packages/design_system` com tema Material 3, navegação responsiva e estados de preparação.
- Shells Flutter em `apps/cliente`, `apps/painel_proprietario` e `apps/painel_central`; Android/iOS versionados para o cliente e Web para os painéis. APKs Android dos painéis são prévias temporárias e não alteram a decisão D-006.
- Os cinco `pubspec.lock` foram registrados após resolução de dependências, análise e testes no workflow `Fixar dependências Flutter`.
- O workflow `Preparar plataformas Flutter e builds de teste` passou por análise/testes e builds Web. Compilou três APKs Android debug `arm64`; elas estão separadas como assets no [pré-lançamento privado](https://github.com/dasilvagonchoroskie-cpu/gas-plataforma/releases/tag/previa-apks-android-arm64-38507526841), com links e hashes no [guia de instalação](GUIA_APKS_PREVIA.md). O runner Linux gerou arquivos de projeto iOS, mas não compilou nem assinou iOS.

Ainda não há projeto Supabase provisionado, migrations, dados de produção, autenticação ou chaves de serviço no repositório. Os shells não contêm lógica de negócio nem autorização implementada.

## 2. Arquitetura de referência

### Aplicações e módulos

- Monorepo Flutter/Dart, mantendo uma base de código reutilizável.
- `apps/cliente`: app Android/iOS com shell white-label compartilhado; IDs e variantes por empresa aguardam revisão.
- `apps/painel_proprietario`: shell web responsivo para administrar somente o próprio tenant; a decisão D-006 ainda define se haverá app móvel do proprietário.
- `apps/painel_central`: shell web responsivo para operações de uma central atribuída.
- `packages/nucleo`: tipos e regras realmente compartilhados; `packages/design_system`: apresentação compartilhada.
- Organização futura por funcionalidade (`features`) e separação clara entre interface, domínio e acesso a dados. Evitar duplicar regras críticas no app e no servidor.

Os shells não estão conectados a autenticação, backend ou dados de negócio. A composição das plataformas e os guias de prévia estão em `apps/README.md`, `docs/GUIA_BUILDS_TESTE.md` e `docs/GUIA_APKS_PREVIA.md`.

### Serviços de backend

A arquitetura registrada hoje aponta **Supabase** como backend de referência: Postgres, Auth, RLS, Storage, Realtime e Edge Functions, sem microsserviços no piloto. Firebase Cloud Messaging fica restrito a push. O banco transacional de pedidos e empresas deve ter uma única fonte de verdade.

- Firestore não será adicionado como segundo banco nesta etapa; isso duplicaria dados e controles de acesso sem uma necessidade aprovada.
- Render ainda não foi selecionado. A hospedagem do painel Flutter Web e o processo de deploy devem ser escolhidos após comparar conta, região, custo, backup, operação e segurança.
- Se o arquiteto preferir outro provedor ou uma integração adicional, registrar primeiro uma decisão arquitetural com motivo, dados envolvidos, custos, riscos e plano de migração.

Nenhuma conta de fornecedor foi criada ou conectada por este guia.

## 3. Proposta de isolamento multi-tenant — aguardando revisão

A proposta mantém a identidade de login separada das permissões de negócio:

1. `auth.users` identifica a pessoa autenticada.
2. Um perfil guarda atributos pessoais necessários, sem transformar nome ou telefone em autorização.
3. Uma associação pessoa–empresa concede papéis de gestão/operação dentro de um único tenant. Associação a centrais é uma restrição adicional para operadores.
4. Um cliente pode ter pedidos em mais de uma empresa, mas cada pedido pertence a exatamente uma empresa e identifica o usuário cliente. O cliente não se torna operador dessa empresa por fazer um pedido.
5. O proprietário administra somente a empresa à qual está associado. Administrador global da plataforma continua fora do escopo.

### Regras obrigatórias para o desenho detalhado

- Tabelas de negócio incluem `empresa_id` diretamente ou têm uma relação verificável e protegida até a empresa. Registros vinculados a uma central devem impedir, também por restrição relacional no banco, que `central_id` e `empresa_id` apontem para empresas diferentes.
- RLS começa em negação por padrão e libera cada operação explicitamente. `SELECT`, `INSERT`, `UPDATE` e `DELETE` são testados separadamente.
- O app pode carregar um identificador para escolher a marca, mas nunca é a autoridade para escolher a empresa permitida. O servidor confere `auth.uid()`, associação ativa, papel, central e relação do registro em cada operação.
- Não confiar em filtros do app, telas escondidas, `empresa_id` enviado pelo cliente nem metadados editáveis pelo usuário como barreira de autorização.
- Funções privilegiadas só quando necessárias, com validação do JWT, identidade e papel, permissões mínimas, `search_path` fixo, validação de parâmetros, idempotência nas operações críticas e sem expor a chave `service_role` aos apps.
- Buckets de comprovantes e outros documentos pessoais permanecem privados. Políticas do Storage verificam a associação ao pedido e ao tenant; o nome do caminho do arquivo, sozinho, não é autorização.
- Realtime e notificações obedecem às mesmas permissões. Push e logs não devem incluir endereço, comprovante, telefone ou outros dados pessoais desnecessários.
- Configuração de marca e logo podem ser públicas apenas quando não contêm credenciais, dados privados ou URLs assinadas de acesso temporário.

Os papéis exatos, o ciclo de convite/desativação e os limites de cada central precisam ser aprovados antes de escrever a primeira migration. A matriz proposta e os testes negativos estão detalhados em `MATRIZ_ACESSO_PROPOSTA.md`; ela também aguarda revisão e não deve ser tratada como autorização de implementação.

## 4. Supabase: integração e ambientes

### Ambientes propostos

Manter ambientes separados para desenvolvimento local, homologação e produção, cada qual com projeto, chaves, dados e acesso próprios. Região, plano e localização de dados precisam ser verificados na contratação; não assumir disponibilidade, preço ou conformidade sem checagem atual.

- Desenvolvimento local usa dados sintéticos e o Supabase CLI/Docker, quando o ambiente de desenvolvimento for preparado.
- Homologação valida migrations e testes de isolamento com contas fictícias.
- Produção fica sem deploy automático até aprovação do arquiteto e proteção explícita do ambiente.
- Segredos do servidor ficam no gerenciador de segredos do provedor; deploy futuro pode usar GitHub Environments com aprovação e segredos separados por ambiente.

A URL do Supabase e a chave pública/publishable do cliente não substituem RLS e devem corresponder ao ambiente correto. Chaves privilegiadas (como `service_role`) nunca entram em Flutter, APK/AAB, arquivos versionados, logs ou artefatos de build.

### Fluxo de banco

1. Definir e aprovar o modelo de identidade, memberships, papéis, acesso por central e matriz de permissões.
2. Escrever migrations pequenas, numeradas, revisáveis e idempotentes quando apropriado; sem alteração manual direta em produção.
3. Usar apenas seeds sintéticos e separados das migrations.
4. Rodar migrations e testes em local/homologação antes de qualquer promoção.
5. Testar restauração de backup e isolamento antes do piloto.

A pasta `supabase/` contém guias de preparação. Ela não contém `config.toml`, migration ou projeto conectado neste momento.

## 5. Portões de qualidade e segurança

Antes da primeira migration, o arquiteto deve revisar a matriz de acesso e aprovar os cenários. Os testes de segurança precisam criar, no mínimo, duas empresas independentes e usuários com papéis diferentes, e provar:

- usuário anônimo não acessa dados privados;
- cliente vê somente perfil, endereços e pedidos próprios, mesmo que tente trocar IDs;
- operador vê somente as centrais às quais está associado;
- proprietário não atravessa o limite do próprio tenant;
- leituras e tentativas de escrita cruzada entre empresas são negadas;
- Storage, Realtime, RPC e Edge Functions não permitem contornar a política do banco;
- concorrência não duplica pedido, reserva ou movimento financeiro quando esses módulos forem implementados.

A aprovação de CI não substitui revisão de segurança, testes de integração ou restauração de backup.

## 6. Próximas etapas sugeridas

1. O arquiteto revisar este guia e as pendências D-002 a D-011 em `DECISOES.md`.
2. Aprovar uma matriz concreta de papéis e acesso e um modelo de empresa/usuário/central.
3. Conferir as contas, região, planos, custos, backup e responsabilidades dos fornecedores; só então provisionar desenvolvimento/homologação.
4. Implementar primeira migration e testes negativos de isolamento, sem dados reais.
5. Conectar os apps ao Supabase usando apenas acesso público sujeito a RLS; manter operações privilegiadas no servidor.
6. Evoluir para painel, cliente, Storage, Realtime, push e deploy por etapas, com análise/testes em cada mudança.
7. Deixar certificados, publicação nas lojas e liberação de produção para a revisão final indicada pelo proprietário.
