-- DADOS DE TESTE CLARAMENTE FICTÍCIOS. Nunca carregar dados reais.
-- Executar somente em banco local/temporário de desenvolvimento.

begin;

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'dono.teste@example.invalid', '', now(), '{}'::jsonb, '{"nome":"Dono Teste"}'::jsonb, now(), now()),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'operador.x@example.invalid', '', now(), '{}'::jsonb, '{"nome":"Operador Teste X"}'::jsonb, now(), now()),
  ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'operador.y@example.invalid', '', now(), '{}'::jsonb, '{"nome":"Operador Teste Y"}'::jsonb, now(), now()),
  ('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'cliente.a@example.invalid', '', now(), '{}'::jsonb, '{"nome":"Cliente Teste A"}'::jsonb, now(), now()),
  ('10000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'cliente.b@example.invalid', '', now(), '{}'::jsonb, '{"nome":"Cliente Teste B"}'::jsonb, now(), now());

insert into public.perfis (id, nome, telefone, papel) values
  ('10000000-0000-0000-0000-000000000001', 'Dono Teste', '+55 00 00000-0001', 'dono'),
  ('10000000-0000-0000-0000-000000000002', 'Operador Teste X', '+55 00 00000-0002', 'operador_central'),
  ('10000000-0000-0000-0000-000000000003', 'Operador Teste Y', '+55 00 00000-0003', 'operador_central'),
  ('10000000-0000-0000-0000-000000000004', 'Cliente Teste A', '+55 00 00000-0004', 'cliente'),
  ('10000000-0000-0000-0000-000000000005', 'Cliente Teste B', '+55 00 00000-0005', 'cliente');

insert into public.centrais (id, nome, cidade, uf, ativa, whatsapp, endereco) values
  ('20000000-0000-0000-0000-000000000001', 'Central Teste 1', 'Cidade Teste X', 'GO', true, '+55 00 00000-0101', 'Endereço Fictício 1'),
  ('20000000-0000-0000-0000-000000000002', 'Central Teste 2', 'Cidade Teste Y', 'GO', true, '+55 00 00000-0102', 'Endereço Fictício 2');

insert into public.operadores_central (perfil_id, central_id) values
  ('10000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001'),
  ('10000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000002');

insert into public.produtos (id, nome, categoria, descricao, troca_vasilhame, ativo) values
  ('30000000-0000-0000-0000-000000000001', 'Produto Teste Gás', 'gas', 'Item fictício para testes de isolamento.', true, true),
  ('30000000-0000-0000-0000-000000000002', 'Produto Teste Água', 'agua', 'Item fictício para testes de isolamento.', false, true);

insert into public.precos_central (central_id, produto_id, preco_centavos, disponivel) values
  ('20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 10000, true),
  ('20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000002', 5000, true),
  ('20000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000001', 11000, true),
  ('20000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000002', 5500, true);

insert into public.estoque_central (central_id, produto_id, cheios, vazios, alerta_minimo) values
  ('20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 12, 4, 2),
  ('20000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000002', 20, 0, 3),
  ('20000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000001', 8, 3, 2),
  ('20000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000002', 15, 0, 3);

insert into public.janelas_entrega (id, central_id, dia_semana, hora_inicio, hora_fim, capacidade, ativa) values
  ('40000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 1, '08:00', '10:00', 5, true),
  ('40000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002', 1, '08:00', '10:00', 5, true);

insert into public.enderecos (
  id, cliente_id, central_id, apelido, cep, logradouro, numero, bairro, cidade, complemento, referencia
) values
  ('60000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000001', 'Casa Teste A', '00000-000', 'Rua Fictícia A', '1', 'Bairro Teste X', 'Cidade Teste X', null, 'Referência fictícia A'),
  ('60000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000005', '20000000-0000-0000-0000-000000000002', 'Casa Teste B', '00000-001', 'Rua Fictícia B', '2', 'Bairro Teste Y', 'Cidade Teste Y', null, 'Referência fictícia B');

insert into public.pedidos (
  id, numero, cliente_id, central_id, endereco_apelido, cep_entrega,
  logradouro_entrega, numero_entrega, bairro_entrega, cidade_entrega,
  referencia_entrega, data_entrega, janela_id, status, forma_pagamento,
  subtotal_centavos, taxa_entrega_centavos, total_centavos
) values
  ('50000000-0000-0000-0000-000000000001', 1, '10000000-0000-0000-0000-000000000004', '20000000-0000-0000-0000-000000000001', 'Casa Teste A', '00000-000', 'Rua Fictícia A', '1', 'Bairro Teste X', 'Cidade Teste X', 'Referência fictícia A', current_date + 1, '40000000-0000-0000-0000-000000000001', 'novo', 'dinheiro', 10000, 0, 10000),
  ('50000000-0000-0000-0000-000000000002', 1, '10000000-0000-0000-0000-000000000005', '20000000-0000-0000-0000-000000000002', 'Casa Teste B', '00000-001', 'Rua Fictícia B', '2', 'Bairro Teste Y', 'Cidade Teste Y', 'Referência fictícia B', current_date + 1, '40000000-0000-0000-0000-000000000002', 'novo', 'dinheiro', 11000, 0, 11000);

insert into public.itens_pedido (central_id, pedido_id, produto_id, quantidade, preco_unitario_centavos) values
  ('20000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 1, 10000),
  ('20000000-0000-0000-0000-000000000002', '50000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000001', 1, 11000);

insert into public.historico_status (central_id, pedido_id, status, por_perfil_id) values
  ('20000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 'novo', '10000000-0000-0000-0000-000000000004'),
  ('20000000-0000-0000-0000-000000000002', '50000000-0000-0000-0000-000000000002', 'novo', '10000000-0000-0000-0000-000000000005');

commit;
