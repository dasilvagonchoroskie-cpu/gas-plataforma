-- Testes de permissões (RLS) e regras de negócio.
-- Tudo roda dentro de uma transação desfeita no final: nada fica no banco.
-- As centrais de teste ficam longe das centrais do seed (coordenadas 10, 10),
-- para o teste não depender dos dados de desenvolvimento.

begin;
set local search_path = public, extensions;

select no_plan();

-- ---------------------------------------------------------------------------
-- Utilitários de teste: trocar de usuário
-- ---------------------------------------------------------------------------
create schema testes;
grant usage on schema testes to public;

create function testes.como(p_id uuid) returns void
language plpgsql as $$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', p_id, 'role', 'authenticated')::text,
    true
  );
  set local role authenticated;
end;
$$;

create function testes.como_anonimo() returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  set local role anon;
end;
$$;

create function testes.como_admin() returns void
language plpgsql as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '', true);
end;
$$;

-- Janela de entrega previsível: uma por dia da semana em cada central de teste.
create function testes.janela(p_central text, p_data date) returns uuid
language sql immutable as $$
  select ('c00000' || p_central || '-0000-4000-8000-00000000000' || extract(dow from p_data)::int)::uuid
$$;

grant execute on all functions in schema testes to public;

-- ---------------------------------------------------------------------------
-- Dados de teste
-- ---------------------------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data) values
  ('a0000000-0000-4000-8000-000000000001', 'dono@teste.invalid', '{"nome":"Dono Teste","telefone":"64900000001"}'),
  ('a0000000-0000-4000-8000-000000000002', 'op.a@teste.invalid', '{"nome":"Operador A","telefone":"64900000002"}'),
  ('a0000000-0000-4000-8000-000000000003', 'op.b@teste.invalid', '{"nome":"Operador B","telefone":"64900000003"}'),
  ('a0000000-0000-4000-8000-000000000004', 'cli.1@teste.invalid', '{"nome":"Cliente Um","telefone":"(64) 99999-0004","papel":"dono"}'),
  ('a0000000-0000-4000-8000-000000000005', 'cli.2@teste.invalid', '{"nome":"Cliente Dois","telefone":"64999990005"}');

select is(
  (select papel::text from public.perfis where id = 'a0000000-0000-4000-8000-000000000004'),
  'cliente',
  'Cadastro cria perfil de cliente mesmo se o app tentar mandar outro papel'
);
select is(
  (select telefone from public.perfis where id = 'a0000000-0000-4000-8000-000000000004'),
  '64999990004',
  'Cadastro guarda só os dígitos do telefone'
);

update public.perfis set papel = 'dono' where id = 'a0000000-0000-4000-8000-000000000001';
update public.perfis set papel = 'operador_central'
where id in ('a0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000003');

insert into public.centrais (id, nome, cidade, uf, latitude, longitude, ativa) values
  ('b0000000-0000-4000-8000-00000000000a', 'Central Teste A', 'Cidade A', 'GO', 10.0, 10.0, true),
  ('b0000000-0000-4000-8000-00000000000b', 'Central Teste B', 'Cidade B', 'GO', 10.5, 10.0, true);

insert into public.operadores_central (perfil_id, central_id) values
  ('a0000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-00000000000a'),
  ('a0000000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-00000000000b');

select throws_ok(
  $$ insert into public.operadores_central (perfil_id, central_id)
     values ('a0000000-0000-4000-8000-000000000004', 'b0000000-0000-4000-8000-00000000000a') $$,
  '23514', null,
  'Cliente não pode ser vinculado como operador de central'
);

insert into public.faixas_entrega (central_id, ate_km, taxa_entrega_centavos) values
  ('b0000000-0000-4000-8000-00000000000a', 5, 0),
  ('b0000000-0000-4000-8000-00000000000a', 30, 700),
  ('b0000000-0000-4000-8000-00000000000b', 30, 300);

insert into public.produtos (id, nome, categoria, troca_vasilhame) values
  ('d0000000-0000-4000-8000-000000000001', 'Gás Teste', 'gas', true),
  ('d0000000-0000-4000-8000-000000000002', 'Água Teste', 'agua', false);

insert into public.precos_central (central_id, produto_id, preco_centavos, disponivel) values
  ('b0000000-0000-4000-8000-00000000000a', 'd0000000-0000-4000-8000-000000000001', 10000, true),
  ('b0000000-0000-4000-8000-00000000000a', 'd0000000-0000-4000-8000-000000000002', 1500, true),
  ('b0000000-0000-4000-8000-00000000000b', 'd0000000-0000-4000-8000-000000000001', 11000, true),
  ('b0000000-0000-4000-8000-00000000000b', 'd0000000-0000-4000-8000-000000000002', 1600, false);

insert into public.estoque_central (central_id, produto_id, cheios, vazios) values
  ('b0000000-0000-4000-8000-00000000000a', 'd0000000-0000-4000-8000-000000000001', 5, 0),
  ('b0000000-0000-4000-8000-00000000000b', 'd0000000-0000-4000-8000-000000000001', 9, 0);

insert into public.janelas_entrega (id, central_id, dia_semana, hora_inicio, hora_fim, capacidade)
select ('c00000' || c.letra || '-0000-4000-8000-00000000000' || d)::uuid, c.id, d, '08:00', '12:00', 2
from (values ('0a', 'b0000000-0000-4000-8000-00000000000a'::uuid),
             ('0b', 'b0000000-0000-4000-8000-00000000000b'::uuid)) as c (letra, id)
cross join generate_series(0, 6) as d;

insert into public.enderecos (id, cliente_id, apelido, cep, logradouro, numero, bairro, cidade, uf, latitude, longitude) values
  ('e0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000004', 'Casa', '75600-000', 'Rua Um', '10', 'Centro', 'Cidade A', 'go', 10.01, 10.0),
  ('e0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000005', 'Casa', '75600000', 'Rua Dois', '20', 'Centro', 'Cidade B', 'GO', 10.48, 10.0),
  ('e0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000004', 'Sítio', '75600000', 'Estrada', 'km 9', 'Zona rural', 'Longe', 'GO', 12.0, 12.0);

select is(
  (select cep || '/' || uf from public.enderecos where id = 'e0000000-0000-4000-8000-000000000001'),
  '75600000/GO',
  'Endereço é normalizado (CEP só dígitos, UF maiúscula)'
);

-- ---------------------------------------------------------------------------
-- Sem login: nada
-- ---------------------------------------------------------------------------
select testes.como_anonimo();

select throws_ok(
  $$ select * from public.produtos $$,
  '42501', null,
  'Sem login não lê o catálogo'
);
select throws_ok(
  $$ select * from public.pedidos $$,
  '42501', null,
  'Sem login não lê pedidos'
);
select throws_ok(
  $$ select public.atendimento_para_coordenadas(10, 10) $$,
  '42501', null,
  'Sem login não chama funções do banco'
);

-- ---------------------------------------------------------------------------
-- Cliente 1 (perto da central A)
-- ---------------------------------------------------------------------------
select testes.como('a0000000-0000-4000-8000-000000000004');

select is(
  (select central_id from public.atendimento_para_endereco('e0000000-0000-4000-8000-000000000001')),
  'b0000000-0000-4000-8000-00000000000a'::uuid,
  'Endereço do cliente 1 é atendido pela central mais próxima (A)'
);
select is(
  (select taxa_entrega_centavos from public.atendimento_para_endereco('e0000000-0000-4000-8000-000000000001')),
  0,
  'Taxa da primeira faixa (até 5 km) é aplicada'
);
select is(
  (select count(*)::integer from public.atendimento_para_endereco('e0000000-0000-4000-8000-000000000003')),
  0,
  'Endereço fora do alcance de todas as centrais não é atendido'
);

select ok(
  exists (
    select 1 from public.agenda_disponivel('b0000000-0000-4000-8000-00000000000a', 3)
    where data = public.hoje_local() + 1 and vagas = 2
  ),
  'Agenda mostra o horário de amanhã com as 2 vagas'
);

select throws_ok(
  $$ select public.criar_pedido(
       'e0000000-0000-4000-8000-000000000003', public.hoje_local() + 1,
       testes.janela('0a', public.hoje_local() + 1), 'dinheiro',
       '[{"produto_id":"d0000000-0000-4000-8000-000000000001","quantidade":1}]',
       'f0000000-0000-4000-8000-0000000000f0') $$,
  'P0001', 'Ainda não entregamos nesse endereço.',
  'Pedido para endereço fora do alcance é recusado'
);

-- Preço e total enviados pelo app são ignorados; repetidos são somados.
select is(
  (public.criar_pedido(
     'e0000000-0000-4000-8000-000000000001', public.hoje_local() + 1,
     testes.janela('0a', public.hoje_local() + 1), 'dinheiro',
     '[{"produto_id":"d0000000-0000-4000-8000-000000000001","quantidade":2,"preco_centavos":1},
       {"produto_id":"d0000000-0000-4000-8000-000000000001","quantidade":1},
       {"produto_id":"d0000000-0000-4000-8000-000000000002","quantidade":1,"total_centavos":1}]',
     'f0000000-0000-4000-8000-000000000001', 50000, 'Portão azul') ->> 'total_centavos')::integer,
  31500,
  'Total calculado no servidor: 3 gás + 1 água, sem taxa'
);

select is(
  (public.criar_pedido(
     'e0000000-0000-4000-8000-000000000001', public.hoje_local() + 1,
     testes.janela('0a', public.hoje_local() + 1), 'dinheiro',
     '[{"produto_id":"d0000000-0000-4000-8000-000000000002","quantidade":9}]',
     'f0000000-0000-4000-8000-000000000001') ->> 'repetido')::boolean,
  true,
  'Reenvio do mesmo pedido (mesma chave) não cria pedido duplicado'
);
select is(
  (select count(*)::integer from public.pedidos where cliente_id = 'a0000000-0000-4000-8000-000000000004'),
  1,
  'Cliente 1 tem um único pedido após o reenvio'
);
select is(
  (select sum(quantidade)::integer from public.itens_pedido),
  4,
  'Itens gravados com as quantidades somadas'
);

select throws_ok(
  $$ select public.criar_pedido(
       'e0000000-0000-4000-8000-000000000001', public.hoje_local() + 1,
       testes.janela('0a', public.hoje_local() + 1), 'dinheiro',
       '[{"produto_id":"d0000000-0000-4000-8000-000000000002","quantidade":1}]',
       'f0000000-0000-4000-8000-0000000000f1', 100) $$,
  '22023', null,
  'Troco menor que o total é recusado'
);

select lives_ok(
  $$ select public.criar_pedido(
       'e0000000-0000-4000-8000-000000000001', public.hoje_local() + 1,
       testes.janela('0a', public.hoje_local() + 1), 'pix_na_entrega',
       '[{"produto_id":"d0000000-0000-4000-8000-000000000001","quantidade":1}]',
       'f0000000-0000-4000-8000-000000000002') $$,
  'Segundo pedido ocupa a última vaga do horário'
);

select throws_ok(
  $$ select public.criar_pedido(
       'e0000000-0000-4000-8000-000000000001', public.hoje_local() + 1,
       testes.janela('0a', public.hoje_local() + 1), 'pix_na_entrega',
       '[{"produto_id":"d0000000-0000-4000-8000-000000000001","quantidade":1}]',
       'f0000000-0000-4000-8000-000000000003') $$,
  'P0001', 'Esse horário acabou de lotar. Escolha outro horário.',
  'Horário lotado não aceita mais pedidos'
);

select throws_ok(
  $$ select public.criar_pedido(
       'e0000000-0000-4000-8000-000000000001', public.hoje_local() + 1,
       testes.janela('0b', public.hoje_local() + 1), 'pix_na_entrega',
       '[{"produto_id":"d0000000-0000-4000-8000-000000000001","quantidade":1}]',
       'f0000000-0000-4000-8000-0000000000f2') $$,
  'P0001', 'Esse horário não está mais disponível. Escolha outro horário.',
  'Não dá para escolher horário de outra central'
);

select throws_ok(
  $$ insert into public.pedidos (cliente_id, central_id, cliente_nome, cliente_telefone,
       cep_entrega, logradouro_entrega, numero_entrega, bairro_entrega, cidade_entrega,
       uf_entrega, latitude_entrega, longitude_entrega, distancia_km, data_entrega,
       hora_inicio, hora_fim, forma_pagamento, subtotal_centavos, taxa_entrega_centavos,
       total_centavos, chave_idempotencia)
     values ('a0000000-0000-4000-8000-000000000004', 'b0000000-0000-4000-8000-00000000000a',
       'x', '64999990004', '75600000', 'r', '1', 'b', 'c', 'GO', 10, 10, 0, current_date,
       '08:00', '09:00', 'dinheiro', 1, 0, 1, gen_random_uuid()) $$,
  '42501', null,
  'Cliente não grava pedido direto na tabela (só pela função)'
);

select throws_ok(
  $$ update public.perfis set papel = 'dono' where id = 'a0000000-0000-4000-8000-000000000004' $$,
  '42501', null,
  'Cliente não muda o próprio papel'
);

select lives_ok(
  $$ update public.perfis set nome = 'Cliente Um Silva' where id = 'a0000000-0000-4000-8000-000000000004' $$,
  'Cliente altera o próprio nome'
);
select lives_ok(
  $$ insert into public.enderecos (cliente_id, apelido, cep, logradouro, numero, bairro, cidade, uf, latitude, longitude)
     values ('a0000000-0000-4000-8000-000000000004', 'Trabalho', '75.600-001', 'Av. Teste', '200', 'Centro', 'Cidade A', 'GO', 10.02, 10.0) $$,
  'Cliente salva um endereço novo pelo app'
);
select throws_ok(
  $$ insert into public.enderecos (cliente_id, apelido, cep, logradouro, numero, bairro, cidade, uf, latitude, longitude)
     values ('a0000000-0000-4000-8000-000000000005', 'Invasão', '75600001', 'Av. Teste', '1', 'Centro', 'Cidade A', 'GO', 10.02, 10.0) $$,
  '42501', null,
  'Cliente não salva endereço em nome de outra pessoa'
);

update public.precos_central set preco_centavos = 1
where central_id = 'b0000000-0000-4000-8000-00000000000a'
  and produto_id = 'd0000000-0000-4000-8000-000000000001';

select throws_ok(
  $$ select public.criar_central('X', 'Y', 'GO', '', 1, 1) $$,
  '42501', null,
  'Cliente não cria central'
);
select throws_ok(
  $$ select public.movimentar_estoque('b0000000-0000-4000-8000-00000000000a',
       'd0000000-0000-4000-8000-000000000001', 'entrada', 100, 0, 'teste') $$,
  '42501', null,
  'Cliente não mexe no estoque'
);

-- ---------------------------------------------------------------------------
-- Cliente 2 (perto da central B)
-- ---------------------------------------------------------------------------
select testes.como('a0000000-0000-4000-8000-000000000005');

select is(
  (select count(*)::integer from public.pedidos),
  0,
  'Cliente 2 não enxerga pedidos do cliente 1'
);
select is(
  (select count(*)::integer from public.enderecos),
  1,
  'Cliente 2 enxerga só o próprio endereço'
);

select is(
  (public.criar_pedido(
     'e0000000-0000-4000-8000-000000000002', public.hoje_local() + 1,
     testes.janela('0b', public.hoje_local() + 1), 'cartao_na_entrega',
     '[{"produto_id":"d0000000-0000-4000-8000-000000000001","quantidade":1}]',
     'f0000000-0000-4000-8000-000000000004') ->> 'total_centavos')::integer,
  11300,
  'Pedido do cliente 2 vai para a central B, com o preço e a taxa dela'
);

select throws_ok(
  $$ select public.criar_pedido(
       'e0000000-0000-4000-8000-000000000002', public.hoje_local() + 1,
       testes.janela('0b', public.hoje_local() + 1), 'dinheiro',
       '[{"produto_id":"d0000000-0000-4000-8000-000000000002","quantidade":1}]',
       'f0000000-0000-4000-8000-0000000000f3') $$,
  'P0001', 'O produto Água Teste não está disponível agora.',
  'Produto indisponível na central não pode ser pedido'
);

-- ---------------------------------------------------------------------------
-- Operador da central A
-- ---------------------------------------------------------------------------
select testes.como('a0000000-0000-4000-8000-000000000002');

select is(
  (select count(*)::integer from public.pedidos),
  2,
  'Operador A vê os dois pedidos da central A'
);
select is(
  (select count(*)::integer from public.pedidos where central_id = 'b0000000-0000-4000-8000-00000000000b'),
  0,
  'Operador A não vê pedidos da central B'
);
select is(
  (select count(*)::integer from public.estoque_central where central_id = 'b0000000-0000-4000-8000-00000000000b'),
  0,
  'Operador A não vê o estoque da central B'
);
select is(
  (select count(*)::integer from public.enderecos),
  0,
  'Operador não lê a lista de endereços dos clientes'
);
select is(
  (select cliente_nome || ' / ' || logradouro_entrega from public.pedidos
   where chave_idempotencia = 'f0000000-0000-4000-8000-000000000001'),
  'Cliente Um / Rua Um',
  'Operador vê nome e endereço copiados no pedido para entregar'
);

select is(
  (select preco_centavos from public.precos_central
   where central_id = 'b0000000-0000-4000-8000-00000000000a'
     and produto_id = 'd0000000-0000-4000-8000-000000000001'),
  10000,
  'Tentativa do cliente de mudar preço não teve efeito'
);
select throws_ok(
  $$ update public.precos_central set preco_centavos = 5
     where central_id = 'b0000000-0000-4000-8000-00000000000a'
       and produto_id = 'd0000000-0000-4000-8000-000000000001' $$,
  '42501', 'Somente o dono pode alterar preços.',
  'Operador não altera o valor do preço'
);
select lives_ok(
  $$ update public.precos_central set disponivel = false
     where central_id = 'b0000000-0000-4000-8000-00000000000a'
       and produto_id = 'd0000000-0000-4000-8000-000000000002' $$,
  'Operador marca produto como indisponível na própria central'
);
select lives_ok(
  $$ update public.precos_central set disponivel = true
     where central_id = 'b0000000-0000-4000-8000-00000000000a'
       and produto_id = 'd0000000-0000-4000-8000-000000000002' $$,
  'Operador volta o produto para disponível'
);

create temp table ids_pedidos on commit drop as
select
  (select id from public.pedidos where chave_idempotencia = 'f0000000-0000-4000-8000-000000000001') as p1,
  (select id from public.pedidos where chave_idempotencia = 'f0000000-0000-4000-8000-000000000002') as p2;
grant select on ids_pedidos to public;

select throws_ok(
  $$ select public.mudar_status_pedido((select p1 from ids_pedidos), 'entregue') $$,
  'P0001', null,
  'Pedido novo não pula direto para entregue'
);
select lives_ok(
  $$ select public.mudar_status_pedido((select p1 from ids_pedidos), 'confirmado') $$,
  'Central confirma o pedido'
);
select lives_ok(
  $$ select public.mudar_status_pedido((select p1 from ids_pedidos), 'em_rota') $$,
  'Central manda o pedido para entrega'
);
select lives_ok(
  $$ select public.mudar_status_pedido((select p1 from ids_pedidos), 'entregue') $$,
  'Central marca como entregue'
);
select is(
  (select cheios || '/' || vazios from public.estoque_central
   where central_id = 'b0000000-0000-4000-8000-00000000000a'
     and produto_id = 'd0000000-0000-4000-8000-000000000001'),
  '2/3',
  'Entrega baixa 3 gás cheios e recebe 3 vazios na troca'
);
select is(
  (select cheios || '/' || vazios from public.estoque_central
   where central_id = 'b0000000-0000-4000-8000-00000000000a'
     and produto_id = 'd0000000-0000-4000-8000-000000000002'),
  '-1/0',
  'Água sem troca baixa só os cheios (estoque negativo não trava a entrega)'
);
select is(
  (select count(*)::integer from public.historico_status
   where pedido_id = (select p1 from ids_pedidos)),
  4,
  'Histórico registra cada mudança de status'
);

select throws_ok(
  $$ select public.mudar_status_pedido((select p2 from ids_pedidos), 'cancelado') $$,
  '22023', 'Informe o motivo do cancelamento.',
  'Central precisa informar o motivo para cancelar'
);

select ok(
  (select produtos_disponiveis from public.opcoes_transferencia((select p2 from ids_pedidos))
   where central_id = 'b0000000-0000-4000-8000-00000000000b'),
  'Opções de transferência mostram que a central B tem o produto'
);

select throws_ok(
  $$ select public.transferir_pedido((select p2 from ids_pedidos), 'b0000000-0000-4000-8000-00000000000b', '') $$,
  '22023', 'Informe o motivo da transferência.',
  'Transferência exige motivo'
);
select lives_ok(
  $$ select public.transferir_pedido((select p2 from ids_pedidos), 'b0000000-0000-4000-8000-00000000000b',
       'Sem gás em estoque') $$,
  'Central A transfere o pedido para a central B'
);
select is(
  (select count(*)::integer from public.pedidos where id = (select p2 from ids_pedidos)),
  0,
  'Depois da transferência, a central A não vê mais o pedido'
);
select is(
  (select count(*)::integer from public.transferencias_pedido),
  1,
  'Central A vê o registro da transferência que fez'
);
select throws_ok(
  $$ select public.movimentar_estoque('b0000000-0000-4000-8000-00000000000b',
       'd0000000-0000-4000-8000-000000000001', 'entrada', 1, 0, 'teste') $$,
  '42501', null,
  'Operador A não mexe no estoque da central B'
);
select is(
  (public.movimentar_estoque('b0000000-0000-4000-8000-00000000000a',
     'd0000000-0000-4000-8000-000000000001', 'entrada', 10, 3, 'Chegou carga') ->> 'cheios')::integer,
  12,
  'Entrada soma cheios e devolve vazios ao fornecedor'
);
select is(
  (public.movimentar_estoque('b0000000-0000-4000-8000-00000000000a',
     'd0000000-0000-4000-8000-000000000001', 'contagem', 20, 1, 'Contagem do dia')
   ->> 'vazios')::integer,
  1,
  'Contagem define as quantidades contadas'
);
select is(
  (select count(*)::integer from public.movimentos_estoque
   where central_id = 'b0000000-0000-4000-8000-00000000000a'),
  4,
  'Cada movimento de estoque fica registrado (2 entregas, 1 entrada, 1 contagem)'
);
select throws_ok(
  $$ select * from public.resumo_centrais(public.hoje_local(), public.hoje_local(),
       'b0000000-0000-4000-8000-00000000000b') $$,
  '42501', null,
  'Operador A não vê relatório da central B'
);
select is(
  (select faturamento_centavos from public.resumo_centrais(public.hoje_local(), public.hoje_local())),
  31500::bigint,
  'Relatório da central A mostra o faturamento do pedido entregue'
);

select lives_ok(
  $$ insert into public.entregadores (central_id, nome, telefone)
     values ('b0000000-0000-4000-8000-00000000000a', 'João Entregador', '64 98888-0000') $$,
  'Operador A cadastra entregador na própria central'
);
select throws_ok(
  $$ select public.atribuir_entregador((select p1 from ids_pedidos),
       (select id from public.entregadores where nome = 'João Entregador')) $$,
  'P0001', 'Pedido já encerrado.',
  'Não dá para trocar o entregador de pedido entregue'
);

select throws_ok(
  $$ insert into public.entregadores (central_id, nome)
     values ('b0000000-0000-4000-8000-00000000000b', 'Intruso') $$,
  '42501', null,
  'Operador A não cadastra entregador na central B'
);

-- ---------------------------------------------------------------------------
-- Operador da central B
-- ---------------------------------------------------------------------------
select testes.como('a0000000-0000-4000-8000-000000000003');

select is(
  (select status::text || '/' || transferencias from public.pedidos where id = (select p2 from ids_pedidos)),
  'novo/1',
  'Central B recebe o pedido transferido como novo'
);
select is(
  (select janela_id from public.pedidos where id = (select p2 from ids_pedidos)),
  testes.janela('0b', public.hoje_local() + 1),
  'Pedido transferido ocupa o mesmo horário na central B'
);
select is(
  (select count(*)::integer from public.historico_status
   where pedido_id = (select p2 from ids_pedidos) and evento = 'transferencia'),
  1,
  'Histórico mostra a transferência para a central B'
);
select throws_ok(
  $$ select public.mudar_status_pedido((select p1 from ids_pedidos), 'cancelado', 'x') $$,
  'P0002', null,
  'Operador B não mexe em pedido da central A'
);
select is(
  (select count(*)::integer from public.auditoria),
  0,
  'Operador não lê a auditoria'
);

-- ---------------------------------------------------------------------------
-- Cliente 1 de novo: cancelar e excluir conta
-- ---------------------------------------------------------------------------
select testes.como('a0000000-0000-4000-8000-000000000004');

select lives_ok(
  $$ select public.criar_pedido(
       'e0000000-0000-4000-8000-000000000001', public.hoje_local() + 1,
       testes.janela('0a', public.hoje_local() + 1), 'dinheiro',
       '[{"produto_id":"d0000000-0000-4000-8000-000000000002","quantidade":2}]',
       'f0000000-0000-4000-8000-000000000005') $$,
  'Com a vaga liberada pela transferência, o cliente faz outro pedido na central A'
);
select throws_ok(
  $$ select public.mudar_status_pedido(
       (select id from public.pedidos where chave_idempotencia = 'f0000000-0000-4000-8000-000000000005'),
       'confirmado') $$,
  '42501', null,
  'Cliente não confirma o próprio pedido'
);
select throws_ok(
  $$ select public.mudar_status_pedido((select p1 from ids_pedidos), 'cancelado') $$,
  'P0001', null,
  'Cliente não cancela pedido já entregue'
);
select lives_ok(
  $$ select public.mudar_status_pedido((select p2 from ids_pedidos), 'cancelado') $$,
  'Cliente cancela pedido novo (mesmo depois de transferido)'
);
select throws_ok(
  $$ select public.anonimizar_minha_conta() $$,
  'P0001', null,
  'Conta com pedido em andamento não pode ser excluída'
);

-- ---------------------------------------------------------------------------
-- Dono
-- ---------------------------------------------------------------------------
select testes.como('a0000000-0000-4000-8000-000000000001');

select ok(
  (select count(*) from public.pedidos) >= 4,
  'Dono vê os pedidos de todas as centrais'
);
select lives_ok(
  $$ update public.precos_central set preco_centavos = 10500
     where central_id = 'b0000000-0000-4000-8000-00000000000a'
       and produto_id = 'd0000000-0000-4000-8000-000000000001' $$,
  'Dono altera preço'
);
select ok(
  (select count(*) from public.auditoria where tabela = 'precos_central') >= 1,
  'Mudanças de preço ficam na auditoria'
);
select lives_ok(
  $$ update public.centrais set whatsapp = '(64) 99999-1234', endereco = 'Rua Nova, 5'
     where id = 'b0000000-0000-4000-8000-00000000000a' $$,
  'Dono edita os dados da central'
);
select is(
  (select por_perfil_id from public.auditoria where tabela = 'centrais' order by id desc limit 1),
  'a0000000-0000-4000-8000-000000000001'::uuid,
  'Auditoria registra quem alterou a central'
);

create temp table nova_central on commit drop as
select public.criar_central('Central Nova', 'Cidade Nova', 'go', 'Rua Teste, 1', 10.2, 10.0,
  '(64) 3000-0000', true, 'b0000000-0000-4000-8000-00000000000a') as id;
grant select on nova_central to public;

select is(
  (select count(*)::integer from public.precos_central where central_id = (select id from nova_central)),
  2,
  'Nova central copia os preços da central modelo'
);
select is(
  (select count(*)::integer from public.janelas_entrega where central_id = (select id from nova_central)),
  7,
  'Nova central copia os horários da central modelo'
);
select is(
  (select whatsapp from public.centrais where id = (select id from nova_central)),
  '6430000000',
  'WhatsApp da central fica só com dígitos'
);
select is(
  (select central_id from public.atendimento_para_coordenadas(10.19, 10.0)),
  (select id from nova_central),
  'Endereço próximo da central nova passa a ser atendido por ela automaticamente'
);
create temp table central_sem_modelo on commit drop as
select public.criar_central('Central Sem Modelo', 'Cidade X', 'GO', '', 11.0, 11.0) as id;
grant select on central_sem_modelo to public;

select is(
  (select count(*)::integer from public.janelas_entrega
   where central_id = (select id from central_sem_modelo)),
  12,
  'Central sem modelo recebe horários padrão (segunda a sábado, dois turnos)'
);
select is(
  (select ativa from public.centrais where id = (select id from central_sem_modelo)),
  false,
  'Central nova começa desativada quando o dono não pede para ativar'
);

-- ---------------------------------------------------------------------------
-- Cliente 2: exclusão de conta
-- ---------------------------------------------------------------------------
select testes.como('a0000000-0000-4000-8000-000000000003');
select lives_ok(
  $$ select public.mudar_status_pedido(
       (select id from public.pedidos where chave_idempotencia = 'f0000000-0000-4000-8000-000000000004'),
       'cancelado', 'Cliente desistiu por telefone') $$,
  'Central B cancela o pedido do cliente 2 com motivo'
);

select testes.como_admin();
create temp table pedido_do_cliente_1 on commit drop as
select id from public.pedidos where chave_idempotencia = 'f0000000-0000-4000-8000-000000000005';
grant select on pedido_do_cliente_1 to public;

select testes.como('a0000000-0000-4000-8000-000000000005');
select throws_ok(
  $$ select public.mudar_status_pedido((select id from pedido_do_cliente_1), 'cancelado') $$,
  'P0002', null,
  'Cliente não cancela pedido de outro cliente, mesmo sabendo o código'
);
select throws_ok(
  $$ select public.transferir_pedido((select id from pedido_do_cliente_1),
       'b0000000-0000-4000-8000-00000000000b', 'tentativa') $$,
  'P0002', null,
  'Cliente não transfere pedidos'
);
select throws_ok(
  $$ select * from public.opcoes_transferencia((select id from pedido_do_cliente_1)) $$,
  'P0002', null,
  'Cliente não consulta opções de transferência'
);
select throws_ok(
  $$ select public.atribuir_entregador((select id from pedido_do_cliente_1), null) $$,
  'P0002', null,
  'Cliente não escolhe entregador'
);
select throws_ok(
  $$ select * from public.resumo_centrais(public.hoje_local(), public.hoje_local()) $$,
  '42501', null,
  'Cliente não vê relatórios'
);
select lives_ok(
  $$ select public.registrar_dispositivo('token-de-teste-123456', 'android') $$,
  'Cliente registra o aparelho para notificações'
);
select lives_ok(
  $$ select public.anonimizar_minha_conta() $$,
  'Cliente sem pedido em andamento exclui a conta'
);

select testes.como_admin();
select is(
  (select nome || '/' || ativo from public.perfis where id = 'a0000000-0000-4000-8000-000000000005'),
  'Conta excluída/false',
  'Perfil fica anonimizado'
);
select is(
  (select cliente_nome || '/' || logradouro_entrega from public.pedidos
   where chave_idempotencia = 'f0000000-0000-4000-8000-000000000004'),
  'Cliente removido/Endereço removido',
  'Pedidos do cliente excluído ficam sem dados pessoais'
);
select is(
  (select count(*)::integer from public.enderecos where cliente_id = 'a0000000-0000-4000-8000-000000000005')
  + (select count(*)::integer from public.dispositivos_push where perfil_id = 'a0000000-0000-4000-8000-000000000005'),
  0,
  'Endereços e aparelhos do cliente excluído são apagados'
);

-- Segredos do servidor: só a chave service_role (Edge Functions) pode ler.
select testes.como('a0000000-0000-4000-8000-000000000001');
select throws_ok(
  $$ select public.segredo_do_servidor('notificar_segredo') $$,
  '42501',
  null,
  'Nem o dono consegue ler segredos do servidor pelo app'
);
select testes.como_anonimo();
select throws_ok(
  $$ select public.segredo_do_servidor('android_chave_senha') $$,
  '42501',
  null,
  'Visitante não consegue ler segredos do servidor'
);
select testes.como_admin();
select ok(
  has_function_privilege('service_role', 'public.segredo_do_servidor(text)', 'execute'),
  'Edge Functions (service_role) podem ler os segredos permitidos'
);
select ok(
  not has_function_privilege('authenticated', 'public.segredo_do_servidor(text)', 'execute')
  and not has_function_privilege('anon', 'public.segredo_do_servidor(text)', 'execute'),
  'Apps (anon e authenticated) não têm acesso à função de segredos'
);
select ok(
  not has_function_privilege('anon', 'public.criar_pedido(uuid, date, uuid, public.forma_pagamento, jsonb, uuid, integer, text)', 'execute')
  and not has_function_privilege('anon', 'public.anonimizar_minha_conta()', 'execute')
  and not has_function_privilege('anon', 'public.tg_auditar()', 'execute'),
  'Visitante não executa nenhuma função do sistema'
);
select ok(
  has_function_privilege('authenticated', 'public.registrar_dispositivo(text, text)', 'execute')
  and has_function_privilege('authenticated', 'public.anonimizar_minha_conta()', 'execute')
  and not has_function_privilege('authenticated', 'public.tg_auditar()', 'execute'),
  'Logado só executa as funções liberadas'
);

select * from finish();
rollback;
