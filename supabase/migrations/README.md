# Migrations

Ainda não há migrations. Não criar esquema de produção até que o desenho detalhado de tenant, vínculos de usuário, papéis, centrais e RLS seja revisado e aprovado.

Quando autorizadas, as alterações de banco devem ser pequenas, numeradas e versionadas aqui. Não fazer edição manual direta em produção. Seeds de teste devem usar dados sintéticos e ficar separados das migrations. Toda migration deve vir acompanhada de testes de acesso autorizado e negado, incluindo tentativas entre duas empresas.
