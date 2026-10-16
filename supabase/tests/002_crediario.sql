-- Testes da ficha de cadastro e do crediário (fiado com limite).
-- Roda dentro de uma transação desfeita no final: nada fica no banco.

begin;
set local search_path = public, extensions;

select no_plan();

create schema testes;
grant usage on schema testes to public;

create function testes.como(p_id uuid) returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_id, 'role', 'authenticated')::text, true);
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

create function testes.janela(p_central text, p_data date) returns uuid
language sql immutable as $$
  select ('c00000' || p_central || '-0000-4000-8000-00000000000' || extract(dow from p_data)::int)::uuid
$$;

-- Monta a ficha de teste em JSON.
create function testes.ficha(p_cliente uuid, p_cpf text, p_nascimento date, p_endereco uuid) returns jsonb
language sql immutable as $$
  select jsonb_build_object(
    'cpf', p_cpf, 'rg', '1234567', 'data_nascimento', p_nascimento, 'nome_mae', 'Maria Teste',
    'endereco_id', p_endereco, 'empresa', 'Autônomo', 'profissao', 'Motorista',
    'telefone_trabalho', '', 'renda_mensal_centavos', 250000,
    'referencia1_nome', 'José Referência', 'referencia1_telefone', '(64) 99999-1111', 'referencia1_relacao', 'Irmão',
    'referencia2_nome', 'Ana Referência', 'referencia2_telefone', '64999992222', 'referencia2_relacao', 'Vizinha',
    'documento_caminho', p_cliente::text || '/documento.jpg',
    'comprovante_caminho', p_cliente::text || '/comprovante.jpg'
  )
$$;

grant execute on all functions in schema testes to public;

-- ---------------------------------------------------------------------------
-- Dados de teste
-- ---------------------------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data) values
  ('a1000000-0000-4000-8000-000000000001', 'dono2@teste.invalid', '{"nome":"Dono Dois","telefone":"64900000011"}'),
  ('a1000000-0000-4000-8000-000000000002', 'opa2@teste.invalid', '{"nome":"Operador A2","telefone":"64900000012"}'),
  ('a1000000-0000-4000-8000-000000000003', 'opb2@teste.invalid', '{"nome":"Operador B2","telefone":"64900000013"}'),
  ('a1000000-0000-4000-8000-000000000004', 'c1@teste.invalid', '{"nome":"Cliente Fiado","telefone":"64999990014"}'),
  ('a1000000-0000-4000-8000-000000000005', 'c2@teste.invalid', '{"nome":"Cliente Sem Ficha","telefone":"64999990015"}'),
  ('a1000000-0000-4000-8000-000000000006', 'c3@teste.invalid', '{"nome":"Cliente Central","telefone":"64999990016"}');

update public.perfis set papel = 'dono' where id = 'a1000000-0000-4000-8000-000000000001';
update public.perfis set papel = 'operador_central'
where id in ('a1000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-000000000003');

insert into public.centrais (id, nome, cidade, uf, latitude, longitude, ativa) values
  ('b0000000-0000-4000-8000-00000000000a', 'Central A', 'Cidade A', 'GO', 10.0, 10.0, true),
  ('b0000000-0000-4000-8000-00000000000b', 'Central B', 'Cidade B', 'GO', 10.5, 10.0, true);
insert into public.operadores_central (perfil_id, central_id) values
  ('a1000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-00000000000a'),
  ('a1000000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-00000000000b');
insert into public.faixas_entrega (central_id, ate_km, taxa_entrega_centavos) values
  ('b0000000-0000-4000-8000-00000000000a', 30, 0),
  ('b0000000-0000-4000-8000-00000000000b', 30, 0);
insert into public.produtos (id, nome, categoria, troca_vasilhame) values
  ('d0000000-0000-4000-8000-000000000001', 'Gás Teste', 'gas', true);
insert into public.precos_central (central_id, produto_id, preco_centavos) values
  ('b0000000-0000-4000-8000-00000000000a', 'd0000000-0000-4000-8000-000000000001', 10000),
  ('b0000000-0000-4000-8000-00000000000b', 'd0000000-0000-4000-8000-000000000001', 10000);
insert into public.janelas_entrega (id, central_id, dia_semana, hora_inicio, hora_fim, capacidade)
select ('c00000' || c.letra || '-0000-4000-8000-00000000000' || d)::uuid, c.id, d, '08:00', '12:00', 20
from (values ('0a', 'b0000000-0000-4000-8000-00000000000a'::uuid),
             ('0b', 'b0000000-0000-4000-8000-00000000000b'::uuid)) as c (letra, id)
cross join generate_series(0, 6) as d;
insert into public.enderecos (id, cliente_id, apelido, cep, logradouro, numero, bairro, cidade, uf, latitude, longitude) values
  ('e1000000-0000-4000-8000-000000000004', 'a1000000-0000-4000-8000-000000000004', 'Casa', '75600000', 'Rua A', '1', 'Centro', 'Cidade A', 'GO', 10.01, 10.0),
  ('e1000000-0000-4000-8000-000000000005', 'a1000000-0000-4000-8000-000000000005', 'Casa', '75600000', 'Rua B', '2', 'Centro', 'Cidade A', 'GO', 10.02, 10.0),
  ('e1000000-0000-4000-8000-000000000006', 'a1000000-0000-4000-8000-000000000006', 'Casa', '75600000', 'Rua C', '3', 'Centro', 'Cidade A', 'GO', 10.03, 10.0);

-- Fotos já enviadas (simula o upload do app).
insert into storage.buckets (id, name, public) values ('fichas', 'fichas', false) on conflict (id) do nothing;
insert into storage.objects (bucket_id, name) values
  ('fichas', 'a1000000-0000-4000-8000-000000000004/documento.jpg'),
  ('fichas', 'a1000000-0000-4000-8000-000000000004/comprovante.jpg'),
  ('fichas', 'a1000000-0000-4000-8000-000000000006/documento.jpg'),
  ('fichas', 'a1000000-0000-4000-8000-000000000006/comprovante.jpg');

select ok(public.cpf_valido('52998224725') and not public.cpf_valido('52998224724')
  and not public.cpf_valido('11111111111'), 'CPF confere os dígitos verificadores');
select is(public.formatar_reais(123456), 'R$ 1.234,56', 'Valor em reais nas mensagens');

-- ---------------------------------------------------------------------------
-- Ficha obrigatória
-- ---------------------------------------------------------------------------
select testes.como('a1000000-0000-4000-8000-000000000005');
select throws_ok(
  $$ select public.criar_pedido('e1000000-0000-4000-8000-000000000005', public.hoje_local() + 1,
       testes.janela('0a', public.hoje_local() + 1), 'dinheiro',
       '[{"produto_id":"d0000000-0000-4000-8000-000000000001","quantidade":1}]',
       'f1000000-0000-4000-8000-000000000001') $$,
  'P0001', 'Preencha sua ficha de cadastro antes de fazer o pedido.',
  'Cliente sem ficha não consegue pedir'
);

select testes.como('a1000000-0000-4000-8000-000000000004');
select throws_ok(
  $$ select public.enviar_ficha(testes.ficha('a1000000-0000-4000-8000-000000000004', '12345678900',
       '1980-01-01', 'e1000000-0000-4000-8000-000000000004')) $$,
  '22023', 'CPF inválido. Confira os números.',
  'Ficha com CPF inválido é recusada'
);
select throws_ok(
  $$ select public.enviar_ficha(testes.ficha('a1000000-0000-4000-8000-000000000004', '529.982.247-25',
       (public.hoje_local() - interval '17 years')::date, 'e1000000-0000-4000-8000-000000000004')) $$,
  'P0001', 'O cadastro é só para maiores de 18 anos.',
  'Menor de idade não faz cadastro'
);
select throws_ok(
  $$ select public.enviar_ficha(testes.ficha('a1000000-0000-4000-8000-000000000004', '52998224725',
       '1980-01-01', 'e1000000-0000-4000-8000-000000000006')) $$,
  '22023', 'Escolha o endereço onde você mora.',
  'Ficha não aceita endereço de outro cliente'
);
select throws_ok(
  $$ select public.enviar_ficha(testes.ficha('a1000000-0000-4000-8000-000000000005', '52998224725',
       '1980-01-01', 'e1000000-0000-4000-8000-000000000004')) $$,
  '22023', 'Envie as fotos de novo.',
  'Ficha não aceita fotos da pasta de outra pessoa'
);
select lives_ok(
  $$ select public.enviar_ficha(testes.ficha('a1000000-0000-4000-8000-000000000004', '529.982.247-25',
       '1980-01-01', 'e1000000-0000-4000-8000-000000000004')) $$,
  'Cliente envia a ficha completa'
);
select is(
  (select status::text || '/' || central_id::text || '/' || referencia1_telefone from public.fichas_cliente),
  'pendente/b0000000-0000-4000-8000-00000000000a/64999991111',
  'Ficha fica pendente, ligada à central mais próxima e com telefones só em dígitos'
);

select testes.como('a1000000-0000-4000-8000-000000000005');
select throws_ok(
  $$ select public.enviar_ficha(testes.ficha('a1000000-0000-4000-8000-000000000005', '52998224725',
       '1980-01-01', 'e1000000-0000-4000-8000-000000000005')) $$,
  'P0001', 'Este CPF já está em outra conta. Fale com a loja.',
  'O mesmo CPF não entra em duas contas'
);
select is((select count(*)::integer from public.fichas_cliente), 0, 'Cliente não vê a ficha de outro');

-- Storage: ninguém envia foto para a pasta de outra pessoa.
select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('fichas', 'a1000000-0000-4000-8000-000000000004/falsa.jpg') $$,
  '42501', null,
  'Cliente não envia foto para a pasta de outro cliente'
);
select lives_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('fichas', 'a1000000-0000-4000-8000-000000000005/documento.jpg') $$,
  'Cliente envia foto para a própria pasta'
);

-- ---------------------------------------------------------------------------
-- Ficha pendente: pede normal, mas não no fiado
-- ---------------------------------------------------------------------------
select testes.como('a1000000-0000-4000-8000-000000000004');
select lives_ok(
  $$ select public.criar_pedido('e1000000-0000-4000-8000-000000000004', public.hoje_local() + 1,
       testes.janela('0a', public.hoje_local() + 1), 'dinheiro',
       '[{"produto_id":"d0000000-0000-4000-8000-000000000001","quantidade":1}]',
       'f1000000-0000-4000-8000-000000000002') $$,
  'Com a ficha enviada, o cliente já pede pagando na entrega'
);
select throws_ok(
  $$ select public.criar_pedido('e1000000-0000-4000-8000-000000000004', public.hoje_local() + 1,
       testes.janela('0a', public.hoje_local() + 1), 'crediario',
       '[{"produto_id":"d0000000-0000-4000-8000-000000000001","quantidade":1}]',
       'f1000000-0000-4000-8000-000000000003') $$,
  'P0001', 'Seu crediário ainda não foi aprovado. Escolha outra forma de pagamento.',
  'Fiado só depois da aprovação'
);

-- ---------------------------------------------------------------------------
-- Quem aprova: o dono (central só se liberado)
-- ---------------------------------------------------------------------------
select testes.como('a1000000-0000-4000-8000-000000000002');
select is((select count(*)::integer from public.fichas_cliente), 0,
  'Central não vê fichas enquanto o dono não liberar');
select throws_ok(
  $$ select * from public.listar_fichas() $$, '42501', null,
  'Central não lista fichas enquanto o dono não liberar'
);
select throws_ok(
  $$ select public.analisar_ficha('a1000000-0000-4000-8000-000000000004', 'aprovada', 50000) $$,
  'P0002', 'Ficha não encontrada.',
  'Central não aprova ficha enquanto o dono não liberar'
);

select testes.como('a1000000-0000-4000-8000-000000000001');
select is(
  (select count(*)::integer from public.listar_fichas('pendente')), 1,
  'Dono vê a ficha pendente'
);
select is(
  (public.ficha_completa('a1000000-0000-4000-8000-000000000004') ->> 'cpf'), '52998224725',
  'Dono abre a ficha completa'
);
select throws_ok(
  $$ select public.analisar_ficha('a1000000-0000-4000-8000-000000000004', 'recusada') $$,
  '22023', 'Informe o motivo da recusa.',
  'Recusar exige motivo'
);
select lives_ok(
  $$ select public.analisar_ficha('a1000000-0000-4000-8000-000000000004', 'aprovada', 20000) $$,
  'Dono aprova com limite de R$ 200,00'
);

select testes.como('a1000000-0000-4000-8000-000000000004');
select throws_ok(
  $$ select public.enviar_ficha(testes.ficha('a1000000-0000-4000-8000-000000000004', '52998224725',
       '1980-01-01', 'e1000000-0000-4000-8000-000000000004')) $$,
  'P0001', 'Sua ficha já foi aprovada. Para mudar algum dado, fale com a loja.',
  'Ficha aprovada não é alterada pelo cliente'
);
select is(
  (public.resumo_credito() ->> 'disponivel_centavos')::integer, 20000,
  'Cliente vê o limite livre'
);

-- ---------------------------------------------------------------------------
-- Fiado com limite
-- ---------------------------------------------------------------------------
select lives_ok(
  $$ select public.criar_pedido('e1000000-0000-4000-8000-000000000004', public.hoje_local() + 1,
       testes.janela('0a', public.hoje_local() + 1), 'crediario',
       '[{"produto_id":"d0000000-0000-4000-8000-000000000001","quantidade":1}]',
       'f1000000-0000-4000-8000-000000000004') $$,
  'Cliente aprovado pede no fiado'
);
select is(
  (public.resumo_credito() ->> 'reservado_centavos')::integer || '/' || (public.resumo_credito() ->> 'disponivel_centavos'),
  '10000/10000',
  'Pedido fiado em aberto reserva o limite'
);
select throws_ok(
  $$ select public.criar_pedido('e1000000-0000-4000-8000-000000000004', public.hoje_local() + 1,
       testes.janela('0a', public.hoje_local() + 1), 'crediario',
       '[{"produto_id":"d0000000-0000-4000-8000-000000000001","quantidade":2}]',
       'f1000000-0000-4000-8000-000000000005') $$,
  'P0001', 'O pedido passa do seu limite livre no crediário (R$ 100,00). Escolha outra forma de pagamento.',
  'Pedido acima do limite livre é recusado'
);

-- Central entrega: a compra entra na conta.
select testes.como('a1000000-0000-4000-8000-000000000002');
select public.mudar_status_pedido(
  (select id from public.pedidos where chave_idempotencia = 'f1000000-0000-4000-8000-000000000004'), 'confirmado');
select public.mudar_status_pedido(
  (select id from public.pedidos where chave_idempotencia = 'f1000000-0000-4000-8000-000000000004'), 'em_rota');
select public.mudar_status_pedido(
  (select id from public.pedidos where chave_idempotencia = 'f1000000-0000-4000-8000-000000000004'), 'entregue');

select is(
  (public.resumo_credito('a1000000-0000-4000-8000-000000000004') ->> 'devido_centavos')::integer || '/'
    || (public.resumo_credito('a1000000-0000-4000-8000-000000000004') ->> 'reservado_centavos'),
  '10000/0',
  'Pedido fiado entregue vira dívida e libera a reserva'
);
select is(
  (select count(*)::integer from public.devedores()), 1,
  'Central vê quem deve entre os clientes dela'
);
select throws_ok(
  $$ select public.registrar_pagamento_credito('a1000000-0000-4000-8000-000000000004', 20000, 'dinheiro') $$,
  'P0001', 'O valor passa do que o cliente deve (R$ 100,00).',
  'Pagamento não passa do que o cliente deve'
);
select throws_ok(
  $$ select public.registrar_pagamento_credito('a1000000-0000-4000-8000-000000000004', 1000, 'crediario') $$,
  '22023', 'Escolha como o cliente pagou.',
  'Pagamento precisa da forma real (não fiado)'
);
select is(
  (public.registrar_pagamento_credito('a1000000-0000-4000-8000-000000000004', 4000, 'dinheiro', 'Pagou no balcão')
     ->> 'devido_centavos')::integer,
  6000,
  'Central registra o pagamento e a dívida diminui'
);
select throws_ok(
  $$ select public.ajustar_credito('a1000000-0000-4000-8000-000000000004', -6000, 'Perdão') $$,
  '42501', 'Somente o dono faz ajustes no crediário.',
  'Central não faz ajuste manual'
);

select testes.como('a1000000-0000-4000-8000-000000000003');
select throws_ok(
  $$ select public.registrar_pagamento_credito('a1000000-0000-4000-8000-000000000004', 1000, 'dinheiro') $$,
  'P0002', 'Cliente não encontrado.',
  'Outra central não mexe na conta de cliente que não é dela'
);
select is((select count(*)::integer from public.lancamentos_credito), 0,
  'Outra central não vê o extrato de cliente que não é dela');
select is((select count(*)::integer from public.devedores()), 0,
  'Outra central não vê os devedores da central A');

select testes.como('a1000000-0000-4000-8000-000000000004');
select is((select count(*)::integer from public.lancamentos_credito), 2,
  'Cliente vê o próprio extrato (compra e pagamento)');
select throws_ok(
  $$ select public.registrar_pagamento_credito('a1000000-0000-4000-8000-000000000004', 1000, 'dinheiro') $$,
  'P0002', 'Cliente não encontrado.',
  'Cliente não registra pagamento para si mesmo'
);

-- ---------------------------------------------------------------------------
-- Bloqueio e configurações
-- ---------------------------------------------------------------------------
select testes.como('a1000000-0000-4000-8000-000000000001');
select lives_ok(
  $$ select public.definir_bloqueio_credito('a1000000-0000-4000-8000-000000000004', true, 'Atrasou') $$,
  'Dono bloqueia o fiado'
);
select testes.como('a1000000-0000-4000-8000-000000000004');
select throws_ok(
  $$ select public.criar_pedido('e1000000-0000-4000-8000-000000000004', public.hoje_local() + 1,
       testes.janela('0a', public.hoje_local() + 1), 'crediario',
       '[{"produto_id":"d0000000-0000-4000-8000-000000000001","quantidade":1}]',
       'f1000000-0000-4000-8000-000000000006') $$,
  'P0001', 'Seu crediário está bloqueado. Fale com a loja ou escolha outra forma de pagamento.',
  'Fiado bloqueado não aceita pedido'
);

-- Cliente não muda as configurações.
update public.configuracoes set centrais_aprovam_credito = true;
select testes.como_admin();
select is((select centrais_aprovam_credito from public.configuracoes), false,
  'Cliente não muda as configurações');

-- Dono libera as centrais com teto de R$ 50,00.
select testes.como('a1000000-0000-4000-8000-000000000001');
update public.configuracoes set centrais_aprovam_credito = true, limite_maximo_central_centavos = 5000;

select testes.como('a1000000-0000-4000-8000-000000000006');
select lives_ok(
  $$ select public.enviar_ficha(testes.ficha('a1000000-0000-4000-8000-000000000006', '11144477735',
       '1990-02-02', 'e1000000-0000-4000-8000-000000000006')) $$,
  'Outro cliente envia a ficha'
);

select testes.como('a1000000-0000-4000-8000-000000000003');
select is((select count(*)::integer from public.fichas_cliente), 0,
  'Central B não vê fichas dos clientes da central A');
select throws_ok(
  $$ select public.analisar_ficha('a1000000-0000-4000-8000-000000000006', 'aprovada', 1000) $$,
  'P0002', 'Ficha não encontrada.',
  'Central B não aprova cliente da central A'
);

select testes.como('a1000000-0000-4000-8000-000000000002');
select is((select count(*)::integer from public.listar_fichas()), 2,
  'Com a liberação, a central A vê as fichas dos clientes dela');
select throws_ok(
  $$ select public.analisar_ficha('a1000000-0000-4000-8000-000000000006', 'aprovada', 10000) $$,
  'P0001', 'A central pode liberar no máximo R$ 50,00 de limite.',
  'Central respeita o teto definido pelo dono'
);
select lives_ok(
  $$ select public.analisar_ficha('a1000000-0000-4000-8000-000000000006', 'aprovada', 5000) $$,
  'Central aprova dentro do teto'
);
select testes.como_admin();
select is(
  (select acao from public.auditoria where tabela = 'fichas_cliente' order by id desc limit 1),
  'analisar_ficha',
  'Aprovação fica na auditoria'
);
select is(
  (select (depois ? 'cpf') from public.auditoria where tabela = 'fichas_cliente' order by id desc limit 1),
  false,
  'Auditoria não copia o CPF'
);

-- Com fiado em aberto, o cliente não exclui a conta.
select testes.como('a1000000-0000-4000-8000-000000000004');
select public.mudar_status_pedido(
  (select id from public.pedidos where chave_idempotencia = 'f1000000-0000-4000-8000-000000000002'), 'cancelado');
select throws_ok(
  $$ select public.anonimizar_minha_conta() $$,
  'P0001', 'Você tem valor em aberto no crediário. Acerte com a loja antes de excluir a conta.',
  'Cliente com fiado em aberto não exclui a conta'
);

-- Dono faz ajuste.
select testes.como('a1000000-0000-4000-8000-000000000001');
select is(
  (public.ajustar_credito('a1000000-0000-4000-8000-000000000004', -6000, 'Acerto combinado') ->> 'devido_centavos')::integer,
  0,
  'Dono ajusta a conta com motivo'
);

-- ---------------------------------------------------------------------------
-- Visitante não vê nada
-- ---------------------------------------------------------------------------
select testes.como_anonimo();
select throws_ok($$ select * from public.fichas_cliente $$, '42501', null, 'Visitante não lê fichas');
select throws_ok($$ select * from public.lancamentos_credito $$, '42501', null, 'Visitante não lê o crediário');
select throws_ok($$ select * from public.configuracoes $$, '42501', null, 'Visitante não lê configurações');
select throws_ok($$ select public.resumo_credito() $$, '42501', null, 'Visitante não chama funções do crediário');

select testes.como_admin();
select * from finish();
rollback;
