-- pgTAP: executar somente no banco local/temporário criado pelo workflow manual.
-- Fixtures sintéticas vêm de seed_ficticio.sql.

begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(10);

set local role authenticated;
set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000004';

select extensions.is(
  (select count(*)::integer from public.pedidos
   where id = '50000000-0000-0000-0000-000000000002'),
  0,
  'Cliente Teste A não enxerga o pedido de Cliente Teste B'
);

select extensions.ok(
  not has_column_privilege('authenticated', 'public.precos_central', 'preco_centavos', 'UPDATE'),
  'Cliente autenticado não pode alterar preço'
);

select extensions.ok(
  not has_column_privilege('authenticated', 'public.perfis', 'papel', 'UPDATE'),
  'Cliente autenticado não pode alterar papel'
);

set local "request.jwt.claim.sub" = '10000000-0000-0000-0000-000000000002';

select extensions.is(
  (select count(*)::integer from public.pedidos
   where id = '50000000-0000-0000-0000-000000000002'),
  0,
  'Operador da Central Teste 1 não enxerga pedido da Central Teste 2'
);

select extensions.is(
  (select count(*)::integer from public.pedidos
   where id = '50000000-0000-0000-0000-000000000002'
     and logradouro_entrega = 'Rua Fictícia B'),
  0,
  'Operador da Central Teste 1 não enxerga endereço do pedido da Central Teste 2'
);

reset role;
select extensions.throws_ok(
  $$
    insert into public.bloqueios_agenda (central_id, data, janela_id, motivo)
    values (
      '20000000-0000-0000-0000-000000000001',
      current_date + 2,
      '40000000-0000-0000-0000-000000000002',
      'Tentativa fictícia de cruzar centrais'
    )
  $$,
  '23503',
  'FK composta rejeita janela de outra central em bloqueio'
);

select extensions.throws_ok(
  $$
    insert into public.pedidos (
      numero, cliente_id, central_id, cep_entrega, logradouro_entrega,
      numero_entrega, bairro_entrega, cidade_entrega, data_entrega, janela_id,
      forma_pagamento, subtotal_centavos, taxa_entrega_centavos, total_centavos
    ) values (
      99, '10000000-0000-0000-0000-000000000004',
      '20000000-0000-0000-0000-000000000001', '00000-000', 'Rua Fictícia',
      '99', 'Bairro Teste', 'Cidade Teste X', current_date + 2,
      '40000000-0000-0000-0000-000000000002', 'dinheiro', 0, 0, 0
    )
  $$,
  '23503',
  'FK composta rejeita pedido apontando para janela de outra central'
);

select extensions.throws_ok(
  $$
    insert into public.itens_pedido (
      central_id, pedido_id, produto_id, quantidade, preco_unitario_centavos
    ) values (
      '20000000-0000-0000-0000-000000000001',
      '50000000-0000-0000-0000-000000000002',
      '30000000-0000-0000-0000-000000000001', 1, 10000
    )
  $$,
  '23503',
  'FK composta rejeita item ligado a pedido de outra central'
);

select extensions.throws_ok(
  $$
    insert into public.historico_status (central_id, pedido_id, status, por_perfil_id)
    values (
      '20000000-0000-0000-0000-000000000001',
      '50000000-0000-0000-0000-000000000002',
      'novo', '10000000-0000-0000-0000-000000000001'
    )
  $$,
  '23503',
  'FK composta rejeita histórico ligado a pedido de outra central'
);

select extensions.throws_ok(
  $$
    insert into public.movimentos_estoque (
      central_id, produto_id, tipo, quantidade, motivo, pedido_id, por_perfil_id
    ) values (
      '20000000-0000-0000-0000-000000000001',
      '30000000-0000-0000-0000-000000000001',
      'ajuste', 1, 'Teste de isolamento',
      '50000000-0000-0000-0000-000000000002',
      '10000000-0000-0000-0000-000000000001'
    )
  $$,
  '23503',
  'FK composta rejeita movimento ligado a pedido de outra central'
);

select * from extensions.finish();
rollback;
