# Regras de trabalho — seção 1 da arquitetura

1. Leia `docs/ARQUITETURA.md` inteiro antes de escrever código.
2. Siga a ordem da seção 11. Não pule fases nem crie funções fora do escopo da seção 3.
3. O desenvolvedor é iniciante, não lê código nem inglês. Antes e depois de cada mudança, explique em poucas linhas, em português simples, o que será feito e o que foi feito.
4. Antes de alterar qualquer arquivo, apresente um plano de 3 a 5 linhas e aguarde o OK explícito do desenvolvedor.
5. Faça commits pequenos, com mensagens em português.
6. Ao fim de cada etapa, atualize `docs/PROGRESSO.md` com o que foi feito, o que falta e o próximo passo.
7. Nunca coloque senhas ou chaves secretas no código. Nunca peça que sejam coladas no chat. A chave `service_role` nunca vai para os apps; só a chave pública `anon` pode entrar na configuração do app.
8. Nunca altere o banco de produção diretamente. Toda mudança de banco deve passar por migrations versionadas em `supabase/migrations`.
9. Antes de declarar uma etapa concluída, rode análise estática e testes, e mostre o resultado em português.
10. Nomes de domínio (tabelas, colunas e classes) ficam em português e sem acento: `snake_case` no banco e `PascalCase` em Dart. Elementos do próprio framework podem manter os nomes em inglês.

## Princípio de trabalho

Siga as fases, os requisitos de segurança e o escopo de `docs/ARQUITETURA.md`. Se faltar decisão, acesso ou dado, pare nesse ponto e pergunte; não invente nem substitua decisões aprovadas. Produção fica intocada até a fase e a aprovação previstas na arquitetura.
