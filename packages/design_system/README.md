# Pacote design_system

Pacote Flutter compartilhado pelas interfaces do cliente, proprietário e central.

- `criarTemaPlataforma`: tema Material 3 comum, preparado para receber a identidade visual aprovada.
- `CascaPainel`: navegação responsiva que adapta painel largo e tela estreita.
- `EstadoModuloEmPreparacao`: estado explícito para módulos que ainda não estão conectados a dados.

O pacote fornece apresentação compartilhada, não autenticação nem autorização. Toda permissão deve ser imposta no backend/RLS. As telas de preparação não devem ser tratadas como funcionalidade pronta para produção.
