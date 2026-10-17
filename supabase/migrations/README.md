# Migrations do banco

Cada arquivo é uma mudança versionada do banco, aplicada em ordem pelo número
no começo do nome. O número é o mesmo registrado no projeto Supabase, para o
histórico local e o do servidor baterem.

| Arquivo | O que faz |
|---|---|
| `…112043_tipos_e_tabelas` | Tipos, tabelas, restrições e índices |
| `…112129_funcoes_auxiliares_e_gatilhos` | Quem é dono/operador, distância, normalização, auditoria |
| `…112208_permissoes_e_rls` | Permissões mínimas e RLS em todas as tabelas |
| `…112603_funcoes_de_negocio` | Central mais próxima, agenda, pedido, status, transferência, estoque, criar central |
| `…112700_relatorios` | Resumo por central, por produto e por dia |
| `…115107_segredos_do_servidor` | Leitura de segredos do Vault só pelas Edge Functions |
| `…115737_realtime_storage_notificacoes` | Tempo real, fotos dos produtos, aviso de eventos e travas das funções |
| `…155152_forma_pagamento_crediario` | Nova forma de pagamento "crediário" (fiado) |
| `…155401_crediario` | Configurações, ficha do cliente, conta do crediário, regras do fiado e fotos privadas |
| `…160132_funcoes_de_conta` | Aparelhos para notificação e exclusão de conta (LGPD) |
| `…222759_chave_do_firebase` | Chave do Firebase gravada no Vault só pela função do servidor |

Todos já estão aplicados no projeto de desenvolvimento. As funções do banco
não apagam linhas: na exclusão de conta, quem apaga ficha, endereços, aparelhos
e fotos é a função do servidor `excluir-conta`.

Regras: nunca alterar o banco direto; toda mudança nova vira um arquivo aqui;
segredos nunca entram em migrations (ficam no Vault, cadastrados à parte).

Testes: `scripts/testar_banco_local.sh` (Postgres local) e o fluxo
"Testes do banco" no GitHub (Supabase completo e temporário).
