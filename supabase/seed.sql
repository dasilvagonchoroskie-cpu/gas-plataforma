-- Dados de TESTE para o banco de desenvolvimento. Nunca carregar em produção.
-- Nenhum dado pessoal real: não há clientes nem logins aqui. As coordenadas
-- são aproximadas (centro de cada cidade); o dono ajusta no painel.

insert into public.produtos (id, nome, categoria, descricao, troca_vasilhame, ordem) values
  ('30000000-0000-4000-8000-000000000001', 'Gás P13 (13 kg)', 'gas',
   'Botijão de cozinha. Troca do vasilhame vazio na entrega.', true, 10),
  ('30000000-0000-4000-8000-000000000002', 'Gás P13 com vasilhame', 'gas',
   'Botijão cheio para quem não tem vasilhame para trocar.', false, 20),
  ('30000000-0000-4000-8000-000000000003', 'Água mineral 20 litros', 'agua',
   'Galão retornável. Troca do galão vazio na entrega.', true, 30),
  ('30000000-0000-4000-8000-000000000004', 'Água mineral 20 litros com galão', 'agua',
   'Galão novo cheio, para quem não tem galão para trocar.', false, 40),
  ('30000000-0000-4000-8000-000000000005', 'Água mineral 1,5 litro (fardo com 6)', 'agua',
   'Fardo com 6 garrafas descartáveis.', false, 50)
on conflict (id) do nothing;

insert into public.centrais (id, nome, cidade, uf, endereco, latitude, longitude, whatsapp, ativa) values
  ('20000000-0000-4000-8000-000000000001', 'Central Goiatuba', 'Goiatuba', 'GO',
   'Endereço de teste, Centro', -18.0105, -49.3658, null, true),
  ('20000000-0000-4000-8000-000000000002', 'Central Itumbiara', 'Itumbiara', 'GO',
   'Endereço de teste, Centro', -18.4192, -49.2153, null, false),
  ('20000000-0000-4000-8000-000000000003', 'Central Bom Jesus de Goiás', 'Bom Jesus de Goiás', 'GO',
   'Endereço de teste, Centro', -18.2172, -49.7403, null, false)
on conflict (id) do nothing;

insert into public.precos_central (central_id, produto_id, preco_centavos)
select c.id, p.id, v.preco
from public.centrais as c
cross join (values
  ('30000000-0000-4000-8000-000000000001'::uuid, 11000),
  ('30000000-0000-4000-8000-000000000002'::uuid, 32000),
  ('30000000-0000-4000-8000-000000000003'::uuid, 1500),
  ('30000000-0000-4000-8000-000000000004'::uuid, 4500),
  ('30000000-0000-4000-8000-000000000005'::uuid, 1800)
) as v (produto_id, preco)
join public.produtos as p on p.id = v.produto_id
on conflict do nothing;

insert into public.estoque_central (central_id, produto_id, cheios, vazios, alerta_minimo)
select pc.central_id, pc.produto_id, 40, 10, 5
from public.precos_central as pc
on conflict do nothing;

-- Faixas: até 8 km sem taxa; até 20 km R$ 5,00; até 40 km R$ 12,00.
insert into public.faixas_entrega (central_id, ate_km, taxa_entrega_centavos)
select c.id, f.ate_km, f.taxa
from public.centrais as c
cross join (values (8.0, 0), (20.0, 500), (40.0, 1200)) as f (ate_km, taxa)
on conflict do nothing;

-- Janelas: todos os dias, das 8h às 12h e das 13h às 18h, 15 pedidos cada.
insert into public.janelas_entrega (central_id, dia_semana, hora_inicio, hora_fim, capacidade)
select c.id, d, h.inicio, h.fim, 15
from public.centrais as c
cross join generate_series(0, 6) as d
cross join (values (time '08:00', time '12:00'), (time '13:00', time '18:00')) as h (inicio, fim)
on conflict do nothing;
