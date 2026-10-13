# Orientações do projeto

Leia este arquivo e os documentos em `docs/` antes de qualquer implementação. Não pule as fases aprovadas e não crie funcionalidades fora do escopo autorizado.

## Como trabalhar com Evandro

- Explique em português simples, em poucas linhas, antes e depois de cada alteração.
- Evandro não lê código nem inglês técnico; traduza os termos importantes e explique decisões sem jargão desnecessário.
- Antes de iniciar a implementação, alinhe com Evandro o caso de uso, a arquitetura e as decisões em aberto.
- Não altere nenhum repositório ou projeto que já existia antes deste trabalho. Trabalhe somente neste projeto novo, salvo autorização explícita.
- Faça alterações pequenas e revisáveis; cada commit deve ter uma mensagem curta em português.
- Ao fim de cada etapa, atualize `docs/PROGRESSO.md` com o que foi feito, o que falta e o próximo passo.

## Segurança e privacidade

- Nunca coloque senhas, tokens, chaves privadas ou outros segredos no código, nos commits, nos registros ou nos documentos públicos. Use variáveis de ambiente e cofres de segredos apropriados.
- Nunca use a chave privilegiada do Supabase nos aplicativos Flutter ou no navegador.
- Valide entradas no servidor; não confie em preços, totais, central escolhida, permissões ou capacidade enviados pelo aplicativo.
- Use políticas de acesso no banco para todas as tabelas e arquivos privados. Sem política explícita, sem acesso.
- Proteja dados de localização, endereço, telefone e comprovantes de pagamento; registre apenas o necessário.
- Mudanças de banco só por migrations versionadas. Nunca altere produção diretamente.
- Se houver dúvida de segurança ou de escopo, pare e consulte Evandro antes de implementar.

## Qualidade e entrega

- O produto deve ser de qualidade profissional, organizado, sustentável e pronto para o escopo aprovado; não entregar protótipo descartável.
- Interfaces de aplicativos em Flutter/Dart. A stack definida no documento de arquitetura deve ser respeitada, salvo decisão aprovada.
- Nomes de domínio em português sem acentos: `snake_case` no banco e `PascalCase` em Dart. APIs e nomes próprios dos frameworks podem permanecer em inglês.
- Rode análise estática e testes relevantes antes de declarar uma etapa concluída. Informe os comandos, o resultado e o que não pôde ser verificado.
- Documente como usar, instalar, operar e manter cada parte entregue. Registre decisões arquiteturais e motivos em `docs/DECISOES.md`.
- Não prometa proteção absoluta; descreva controles, riscos residuais e limites conhecidos.
