# Testes de segurança do backend

Ainda não há testes de banco ou funções. Antes da primeira migration, preparar dados sintéticos de pelo menos duas empresas e contas separadas para cliente, proprietário e operador de central.

Os testes devem provar tanto o acesso permitido quanto o negado em leitura e escrita, incluindo alteração de IDs enviados pelo cliente. A cobertura deve incluir RLS, Storage privado, Realtime, RPC/Edge Functions e atribuição a centrais. Um teste que verifica somente a interface ou o filtro da consulta não prova isolamento.

Depois que o Supabase local for configurado, executar os testes no CI com ambiente efêmero e sem segredos de produção. A criação do ambiente e o comando exato dependem da versão do Supabase CLI escolhida pelo arquiteto.
