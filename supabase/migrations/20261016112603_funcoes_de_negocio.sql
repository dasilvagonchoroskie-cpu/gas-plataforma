-- Fase 1 — funções de negócio (RPC).
--
-- Regras centrais:
-- * O app nunca envia preço, taxa ou total: tudo é calculado aqui.
-- * O pedido vai para a central ATIVA mais próxima do endereço cuja maior faixa
--   de entrega alcança aquela distância.
-- * A central pode transferir o pedido para outra central (por exemplo, quando
--   falta a mercadoria). O preço combinado com o cliente é mantido.
-- * Mensagens de erro em português simples, para o app mostrar direto.

-- ---------------------------------------------------------------------------
-- Atendimento: qual central atende um ponto
-- ---------------------------------------------------------------------------

create or replace function public.atendimento_para_coordenadas(
  p_latitude double precision,
  p_longitude double precision
)
returns table (
  central_id uuid,
  central_nome text,
  cidade text,
  uf text,
  whatsapp text,
  distancia_km numeric,
  taxa_entrega_centavos integer
)
language sql
stable
security definer
set search_path = ''
as $$
  with candidatas as (
    select
      c.id,
      c.nome,
      c.cidade,
      c.uf::text as uf,
      c.whatsapp,
      public.distancia_km(p_latitude, p_longitude, c.latitude, c.longitude) as distancia
    from public.centrais as c
    where c.ativa
  )
  select
    cand.id,
    cand.nome,
    cand.cidade,
    cand.uf,
    cand.whatsapp,
    round(cand.distancia::numeric, 2),
    faixa.taxa_entrega_centavos
  from candidatas as cand
  cross join lateral (
    select fe.taxa_entrega_centavos
    from public.faixas_entrega as fe
    where fe.central_id = cand.id
      and fe.ate_km >= cand.distancia
    order by fe.ate_km asc
    limit 1
  ) as faixa
  where p_latitude between -90 and 90
    and p_longitude between -180 and 180
  order by cand.distancia asc, cand.id asc
  limit 1;
$$;

create or replace function public.atendimento_para_endereco(p_endereco_id uuid)
returns table (
  central_id uuid,
  central_nome text,
  cidade text,
  uf text,
  whatsapp text,
  distancia_km numeric,
  taxa_entrega_centavos integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_lat double precision;
  v_lon double precision;
begin
  select e.latitude, e.longitude into v_lat, v_lon
  from public.enderecos as e
  where e.id = p_endereco_id
    and e.cliente_id = auth.uid();

  if not found then
    raise exception 'Endereço não encontrado.' using errcode = 'P0002';
  end if;

  return query
  select * from public.atendimento_para_coordenadas(v_lat, v_lon);
end;
$$;

-- ---------------------------------------------------------------------------
-- Agenda: horários com vaga nos próximos dias
-- ---------------------------------------------------------------------------

-- Antecedência mínima: uma janela do dia só aparece se ainda faltam pelo menos
-- 30 minutos para ela terminar.
create or replace function public.agenda_disponivel(
  p_central_id uuid,
  p_dias integer default 7
)
returns table (
  data date,
  janela_id uuid,
  hora_inicio time,
  hora_fim time,
  vagas integer
)
language sql
stable
security definer
set search_path = ''
as $$
  with dias as (
    select (public.hoje_local() + n)::date as data
    from generate_series(0, least(greatest(coalesce(p_dias, 7), 1), 14) - 1) as n
  )
  select
    d.data,
    j.id,
    j.hora_inicio,
    j.hora_fim,
    (j.capacidade - (
      select count(*)::integer
      from public.pedidos as p
      where p.janela_id = j.id
        and p.data_entrega = d.data
        and p.status <> 'cancelado'::public.status_pedido
    )) as vagas
  from dias as d
  join public.janelas_entrega as j
    on j.dia_semana = extract(dow from d.data)::smallint
  join public.centrais as c on c.id = j.central_id
  where j.central_id = p_central_id
    and j.ativa
    and c.ativa
    and (
      d.data > public.hoje_local()
      or j.hora_fim - interval '30 minutes' > public.agora_local()::time
    )
    and not exists (
      select 1 from public.bloqueios_agenda as b
      where b.central_id = j.central_id
        and b.data = d.data
        and (b.janela_id is null or b.janela_id = j.id)
    )
    and j.capacidade > (
      select count(*)
      from public.pedidos as p
      where p.janela_id = j.id
        and p.data_entrega = d.data
        and p.status <> 'cancelado'::public.status_pedido
    )
  order by d.data, j.hora_inicio;
$$;

-- ---------------------------------------------------------------------------
-- Criar pedido
-- ---------------------------------------------------------------------------

create or replace function public.criar_pedido(
  p_endereco_id uuid,
  p_data_entrega date,
  p_janela_id uuid,
  p_forma_pagamento public.forma_pagamento,
  p_itens jsonb,
  p_chave_idempotencia uuid,
  p_troco_para_centavos integer default 0,
  p_observacao text default null
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_cliente uuid := auth.uid();
  v_perfil public.perfis%rowtype;
  v_endereco public.enderecos%rowtype;
  v_janela public.janelas_entrega%rowtype;
  v_atendimento record;
  v_existente public.pedidos%rowtype;
  v_ocupadas integer;
  v_item jsonb;
  v_itens_agregados jsonb := '{}'::jsonb;
  v_produto_id uuid;
  v_quantidade integer;
  v_subtotal bigint := 0;
  v_preco integer;
  v_produto public.produtos%rowtype;
  v_pedido_id uuid;
  v_numero bigint;
  v_troco integer := coalesce(p_troco_para_centavos, 0);
  v_observacao text := nullif(btrim(coalesce(p_observacao, '')), '');
  v_chave text;
begin
  if v_cliente is null then
    raise exception 'Faça login para pedir.' using errcode = '42501';
  end if;

  select * into v_perfil from public.perfis where id = v_cliente;
  if not found
     or v_perfil.papel <> 'cliente'::public.papel_perfil
     or not v_perfil.ativo
     or v_perfil.excluido_em is not null then
    raise exception 'Somente clientes com conta ativa podem fazer pedidos.' using errcode = '42501';
  end if;

  if p_chave_idempotencia is null then
    raise exception 'Pedido sem identificação. Atualize o aplicativo.' using errcode = '22023';
  end if;

  -- Se o app reenviar o mesmo pedido (internet caiu), devolve o que já existe.
  select * into v_existente
  from public.pedidos
  where cliente_id = v_cliente and chave_idempotencia = p_chave_idempotencia;
  if found then
    return jsonb_build_object(
      'id', v_existente.id,
      'numero', v_existente.numero,
      'central_id', v_existente.central_id,
      'total_centavos', v_existente.total_centavos,
      'repetido', true
    );
  end if;

  if char_length(coalesce(v_perfil.telefone, '')) < 10 then
    raise exception 'Cadastre um telefone com DDD no seu perfil antes de pedir.' using errcode = '22023';
  end if;

  select * into v_endereco
  from public.enderecos
  where id = p_endereco_id and cliente_id = v_cliente;
  if not found then
    raise exception 'Endereço não encontrado.' using errcode = 'P0002';
  end if;

  select * into v_atendimento
  from public.atendimento_para_coordenadas(v_endereco.latitude, v_endereco.longitude);
  if v_atendimento.central_id is null then
    raise exception 'Ainda não entregamos nesse endereço.' using errcode = 'P0001';
  end if;

  -- Janela: precisa ser da central que atende o endereço.
  select * into v_janela
  from public.janelas_entrega
  where id = p_janela_id
  for update;

  if not found or v_janela.central_id <> v_atendimento.central_id then
    raise exception 'Esse horário não está mais disponível. Escolha outro horário.'
      using errcode = 'P0001';
  end if;

  if not v_janela.ativa
     or v_janela.dia_semana <> extract(dow from p_data_entrega)::smallint
     or p_data_entrega < public.hoje_local()
     or p_data_entrega > public.hoje_local() + 13
     or (
       p_data_entrega = public.hoje_local()
       and v_janela.hora_fim - interval '30 minutes' <= public.agora_local()::time
     ) then
    raise exception 'Esse horário não está mais disponível. Escolha outro horário.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1 from public.bloqueios_agenda as b
    where b.central_id = v_janela.central_id
      and b.data = p_data_entrega
      and (b.janela_id is null or b.janela_id = v_janela.id)
  ) then
    raise exception 'A central não faz entregas nesse horário. Escolha outro horário.'
      using errcode = 'P0001';
  end if;

  -- A trava "for update" na janela impede que dois pedidos ocupem a última vaga.
  select count(*) into v_ocupadas
  from public.pedidos
  where janela_id = v_janela.id
    and data_entrega = p_data_entrega
    and status <> 'cancelado'::public.status_pedido;

  if v_ocupadas >= v_janela.capacidade then
    raise exception 'Esse horário acabou de lotar. Escolha outro horário.'
      using errcode = 'P0001';
  end if;

  -- Itens: só produto e quantidade vêm do app. Repetidos são somados.
  if p_itens is null or jsonb_typeof(p_itens) <> 'array' or jsonb_array_length(p_itens) = 0 then
    raise exception 'Seu carrinho está vazio.' using errcode = '22023';
  end if;
  if jsonb_array_length(p_itens) > 20 then
    raise exception 'Pedido com itens demais.' using errcode = '22023';
  end if;

  for v_item in select value from jsonb_array_elements(p_itens)
  loop
    begin
      v_produto_id := (v_item ->> 'produto_id')::uuid;
      v_quantidade := (v_item ->> 'quantidade')::integer;
    exception when others then
      raise exception 'Item do carrinho inválido.' using errcode = '22023';
    end;
    if v_produto_id is null or v_quantidade is null or v_quantidade < 1 then
      raise exception 'Item do carrinho inválido.' using errcode = '22023';
    end if;
    v_chave := v_produto_id::text;
    v_itens_agregados := jsonb_set(
      v_itens_agregados,
      array[v_chave],
      to_jsonb(coalesce((v_itens_agregados ->> v_chave)::integer, 0) + v_quantidade)
    );
  end loop;

  for v_chave, v_quantidade in
    select key, value::integer from jsonb_each_text(v_itens_agregados)
  loop
    if v_quantidade > 50 then
      raise exception 'Quantidade máxima por produto é 50.' using errcode = '22023';
    end if;

    select * into v_produto from public.produtos where id = v_chave::uuid;
    select pc.preco_centavos into v_preco
    from public.precos_central as pc
    where pc.central_id = v_atendimento.central_id
      and pc.produto_id = v_chave::uuid
      and pc.disponivel;

    if v_produto.id is null or not v_produto.ativo or v_preco is null then
      raise exception 'O produto % não está disponível agora.',
        coalesce(v_produto.nome, 'escolhido') using errcode = 'P0001';
    end if;
    v_subtotal := v_subtotal + v_preco::bigint * v_quantidade;
  end loop;

  if v_subtotal > 100000000 then
    raise exception 'Valor do pedido acima do permitido.' using errcode = '22023';
  end if;

  if p_forma_pagamento <> 'dinheiro'::public.forma_pagamento then
    v_troco := 0;
  elsif v_troco < 0 then
    raise exception 'Valor de troco inválido.' using errcode = '22023';
  elsif v_troco > 0 and v_troco < v_subtotal + v_atendimento.taxa_entrega_centavos then
    raise exception 'O valor para troco precisa ser maior que o total do pedido.' using errcode = '22023';
  end if;

  if v_observacao is not null and char_length(v_observacao) > 500 then
    raise exception 'A observação pode ter no máximo 500 letras.' using errcode = '22023';
  end if;

  insert into public.pedidos (
    cliente_id, central_id, cliente_nome, cliente_telefone,
    endereco_apelido, cep_entrega, logradouro_entrega, numero_entrega,
    bairro_entrega, cidade_entrega, uf_entrega, complemento_entrega,
    referencia_entrega, latitude_entrega, longitude_entrega, distancia_km,
    data_entrega, janela_id, hora_inicio, hora_fim, forma_pagamento,
    troco_para_centavos, observacao, subtotal_centavos, taxa_entrega_centavos,
    total_centavos, chave_idempotencia
  ) values (
    v_cliente, v_atendimento.central_id, v_perfil.nome, v_perfil.telefone,
    v_endereco.apelido, v_endereco.cep, v_endereco.logradouro, v_endereco.numero,
    v_endereco.bairro, v_endereco.cidade, v_endereco.uf, v_endereco.complemento,
    v_endereco.referencia, v_endereco.latitude, v_endereco.longitude,
    v_atendimento.distancia_km,
    p_data_entrega, v_janela.id, v_janela.hora_inicio, v_janela.hora_fim,
    p_forma_pagamento, v_troco, v_observacao, v_subtotal::integer,
    v_atendimento.taxa_entrega_centavos,
    (v_subtotal + v_atendimento.taxa_entrega_centavos)::integer,
    p_chave_idempotencia
  )
  returning id, numero into v_pedido_id, v_numero;

  insert into public.itens_pedido (
    pedido_id, produto_id, produto_nome, quantidade, preco_unitario_centavos, troca_vasilhame
  )
  select v_pedido_id, pr.id, pr.nome, (agg.value)::integer, pc.preco_centavos, pr.troca_vasilhame
  from jsonb_each_text(v_itens_agregados) as agg
  join public.produtos as pr on pr.id = agg.key::uuid
  join public.precos_central as pc
    on pc.produto_id = pr.id and pc.central_id = v_atendimento.central_id;

  insert into public.historico_status (pedido_id, central_id, status, evento, por_perfil_id)
  values (v_pedido_id, v_atendimento.central_id, 'novo', 'status', v_cliente);

  return jsonb_build_object(
    'id', v_pedido_id,
    'numero', v_numero,
    'central_id', v_atendimento.central_id,
    'total_centavos', (v_subtotal + v_atendimento.taxa_entrega_centavos)::integer,
    'repetido', false
  );
exception
  when unique_violation then
    -- Duas chamadas simultâneas com a mesma chave: devolve o pedido já gravado.
    select * into v_existente
    from public.pedidos
    where cliente_id = v_cliente and chave_idempotencia = p_chave_idempotencia;
    if found then
      return jsonb_build_object(
        'id', v_existente.id,
        'numero', v_existente.numero,
        'central_id', v_existente.central_id,
        'total_centavos', v_existente.total_centavos,
        'repetido', true
      );
    end if;
    raise;
end;
$$;

-- ---------------------------------------------------------------------------
-- Mudar status
-- ---------------------------------------------------------------------------

-- Transições permitidas:
--   cliente: novo -> cancelado
--   central/dono: novo -> confirmado | cancelado
--                 confirmado -> em_rota | cancelado
--                 em_rota -> entregue | cancelado | confirmado (voltou à central)
-- Cancelamento pela central ou pelo dono sempre exige motivo.
-- Ao entregar, o estoque da central baixa (cheios) e, nos itens com troca de
-- vasilhame, os vazios aumentam.
create or replace function public.mudar_status_pedido(
  p_pedido_id uuid,
  p_novo_status public.status_pedido,
  p_motivo text default null
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_usuario uuid := auth.uid();
  v_pedido public.pedidos%rowtype;
  v_eh_cliente boolean;
  v_eh_central boolean;
  v_motivo text := nullif(btrim(coalesce(p_motivo, '')), '');
  v_item record;
  v_cheios integer;
  v_vazios integer;
begin
  if v_usuario is null then
    raise exception 'Faça login novamente.' using errcode = '42501';
  end if;

  select * into v_pedido from public.pedidos where id = p_pedido_id for update;
  if not found then
    raise exception 'Pedido não encontrado.' using errcode = 'P0002';
  end if;

  v_eh_central := public.pode_acessar_central(v_pedido.central_id);
  v_eh_cliente := v_pedido.cliente_id = v_usuario;

  if not v_eh_central and not v_eh_cliente then
    raise exception 'Pedido não encontrado.' using errcode = 'P0002';
  end if;

  if v_pedido.status = p_novo_status then
    return;
  end if;

  if v_motivo is not null and char_length(v_motivo) > 300 then
    raise exception 'O motivo pode ter no máximo 300 letras.' using errcode = '22023';
  end if;

  if not v_eh_central then
    -- Cliente: só cancela enquanto o pedido é novo.
    if not (v_pedido.status = 'novo' and p_novo_status = 'cancelado') then
      if p_novo_status = 'cancelado' then
        raise exception 'A central já está preparando seu pedido. Para cancelar, fale com a central.'
          using errcode = 'P0001';
      end if;
      raise exception 'Você não pode alterar este pedido.' using errcode = '42501';
    end if;
    v_motivo := coalesce(v_motivo, 'Cancelado pelo cliente');
  else
    if not (
      (v_pedido.status = 'novo' and p_novo_status in ('confirmado', 'cancelado'))
      or (v_pedido.status = 'confirmado' and p_novo_status in ('em_rota', 'cancelado'))
      or (v_pedido.status = 'em_rota' and p_novo_status in ('entregue', 'cancelado', 'confirmado'))
    ) then
      raise exception 'Não é possível mudar o pedido de "%" para "%".',
        v_pedido.status, p_novo_status using errcode = 'P0001';
    end if;
    if p_novo_status = 'cancelado' and v_motivo is null then
      raise exception 'Informe o motivo do cancelamento.' using errcode = '22023';
    end if;
  end if;

  update public.pedidos
  set status = p_novo_status,
      motivo_cancelamento = case when p_novo_status = 'cancelado' then v_motivo else motivo_cancelamento end,
      confirmado_em = case when p_novo_status = 'confirmado' and confirmado_em is null then now() else confirmado_em end,
      saiu_em = case when p_novo_status = 'em_rota' then now() else saiu_em end,
      entregue_em = case when p_novo_status = 'entregue' then now() else entregue_em end,
      cancelado_em = case when p_novo_status = 'cancelado' then now() else cancelado_em end
  where id = v_pedido.id;

  insert into public.historico_status (pedido_id, central_id, status, evento, observacao, por_perfil_id)
  values (
    v_pedido.id,
    v_pedido.central_id,
    p_novo_status,
    'status',
    case
      when p_novo_status = 'cancelado' then v_motivo
      when p_novo_status = 'confirmado' and v_pedido.status = 'em_rota' then
        coalesce(v_motivo, 'Pedido voltou para a central')
      else v_motivo
    end,
    v_usuario
  );

  if p_novo_status = 'entregue' then
    for v_item in
      select ip.produto_id, ip.quantidade, ip.troca_vasilhame
      from public.itens_pedido as ip
      where ip.pedido_id = v_pedido.id
    loop
      insert into public.estoque_central (central_id, produto_id, cheios, vazios)
      values (
        v_pedido.central_id,
        v_item.produto_id,
        -v_item.quantidade,
        case when v_item.troca_vasilhame then v_item.quantidade else 0 end
      )
      on conflict (central_id, produto_id) do update
      set cheios = public.estoque_central.cheios - v_item.quantidade,
          vazios = public.estoque_central.vazios
            + case when v_item.troca_vasilhame then v_item.quantidade else 0 end
      returning cheios, vazios into v_cheios, v_vazios;

      insert into public.movimentos_estoque (
        central_id, produto_id, tipo, delta_cheios, delta_vazios,
        cheios_apos, vazios_apos, motivo, pedido_id, por_perfil_id
      ) values (
        v_pedido.central_id,
        v_item.produto_id,
        'entrega_pedido',
        -v_item.quantidade,
        case when v_item.troca_vasilhame then v_item.quantidade else 0 end,
        v_cheios,
        v_vazios,
        'Entrega do pedido ' || v_pedido.numero,
        v_pedido.id,
        v_usuario
      );
    end loop;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Entregador do pedido
-- ---------------------------------------------------------------------------

create or replace function public.atribuir_entregador(
  p_pedido_id uuid,
  p_entregador_id uuid
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_pedido public.pedidos%rowtype;
  v_entregador public.entregadores%rowtype;
begin
  select * into v_pedido from public.pedidos where id = p_pedido_id for update;
  if not found or not public.pode_acessar_central(v_pedido.central_id) then
    raise exception 'Pedido não encontrado.' using errcode = 'P0002';
  end if;

  if v_pedido.status in ('entregue', 'cancelado') then
    raise exception 'Pedido já encerrado.' using errcode = 'P0001';
  end if;

  if p_entregador_id is not null then
    select * into v_entregador
    from public.entregadores
    where id = p_entregador_id and central_id = v_pedido.central_id;
    if not found or not v_entregador.ativo then
      raise exception 'Entregador não encontrado nesta central.' using errcode = 'P0002';
    end if;
  end if;

  if v_pedido.entregador_id is not distinct from p_entregador_id then
    return;
  end if;

  update public.pedidos set entregador_id = p_entregador_id where id = v_pedido.id;

  insert into public.historico_status (pedido_id, central_id, status, evento, observacao, por_perfil_id)
  values (
    v_pedido.id,
    v_pedido.central_id,
    v_pedido.status,
    'entregador',
    case when p_entregador_id is null then 'Entregador removido'
         else 'Entregador: ' || v_entregador.nome end,
    auth.uid()
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Transferência entre centrais
-- ---------------------------------------------------------------------------

-- Lista as outras centrais ativas, da mais próxima do cliente para a mais
-- longe, dizendo se têm todos os produtos do pedido disponíveis e em estoque.
create or replace function public.opcoes_transferencia(p_pedido_id uuid)
returns table (
  central_id uuid,
  central_nome text,
  cidade text,
  uf text,
  distancia_km numeric,
  produtos_disponiveis boolean,
  estoque_suficiente boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_pedido public.pedidos%rowtype;
begin
  select * into v_pedido from public.pedidos where id = p_pedido_id;
  if not found or not public.pode_acessar_central(v_pedido.central_id) then
    raise exception 'Pedido não encontrado.' using errcode = 'P0002';
  end if;

  return query
  select
    c.id,
    c.nome,
    c.cidade,
    c.uf::text,
    round(public.distancia_km(
      v_pedido.latitude_entrega, v_pedido.longitude_entrega, c.latitude, c.longitude
    )::numeric, 2),
    not exists (
      select 1 from public.itens_pedido as ip
      where ip.pedido_id = v_pedido.id
        and not exists (
          select 1 from public.precos_central as pc
          where pc.central_id = c.id and pc.produto_id = ip.produto_id and pc.disponivel
        )
    ),
    not exists (
      select 1 from public.itens_pedido as ip
      where ip.pedido_id = v_pedido.id
        and coalesce((
          select ec.cheios from public.estoque_central as ec
          where ec.central_id = c.id and ec.produto_id = ip.produto_id
        ), 0) < ip.quantidade
    )
  from public.centrais as c
  where c.ativa
    and c.id <> v_pedido.central_id
  order by 5 asc, c.nome asc;
end;
$$;

create or replace function public.transferir_pedido(
  p_pedido_id uuid,
  p_central_destino_id uuid,
  p_motivo text
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_usuario uuid := auth.uid();
  v_pedido public.pedidos%rowtype;
  v_destino public.centrais%rowtype;
  v_origem public.centrais%rowtype;
  v_motivo text := nullif(btrim(coalesce(p_motivo, '')), '');
  v_janela_destino uuid;
begin
  select * into v_pedido from public.pedidos where id = p_pedido_id for update;
  if not found or not public.pode_acessar_central(v_pedido.central_id) then
    raise exception 'Pedido não encontrado.' using errcode = 'P0002';
  end if;

  if v_pedido.status not in ('novo', 'confirmado') then
    raise exception 'Só é possível transferir pedidos que ainda não saíram para entrega.'
      using errcode = 'P0001';
  end if;

  if v_motivo is null then
    raise exception 'Informe o motivo da transferência.' using errcode = '22023';
  end if;
  if char_length(v_motivo) > 300 then
    raise exception 'O motivo pode ter no máximo 300 letras.' using errcode = '22023';
  end if;

  if v_pedido.transferencias >= 5 then
    raise exception 'Este pedido já foi transferido muitas vezes. Fale com o dono da revenda.'
      using errcode = 'P0001';
  end if;

  select * into v_destino from public.centrais where id = p_central_destino_id;
  if not found or not v_destino.ativa then
    raise exception 'Central de destino não encontrada ou desativada.' using errcode = 'P0002';
  end if;
  if v_destino.id = v_pedido.central_id then
    raise exception 'O pedido já está nesta central.' using errcode = 'P0001';
  end if;

  select * into v_origem from public.centrais where id = v_pedido.central_id;

  -- Mantém o mesmo horário prometido. Se a central de destino tiver uma janela
  -- igual naquele dia, o pedido passa a ocupar uma vaga dela.
  select j.id into v_janela_destino
  from public.janelas_entrega as j
  where j.central_id = v_destino.id
    and j.ativa
    and j.dia_semana = extract(dow from v_pedido.data_entrega)::smallint
    and j.hora_inicio = v_pedido.hora_inicio
    and j.hora_fim = v_pedido.hora_fim
  limit 1;

  update public.pedidos
  set central_id = v_destino.id,
      janela_id = v_janela_destino,
      entregador_id = null,
      status = 'novo',
      confirmado_em = null,
      distancia_km = round(public.distancia_km(
        latitude_entrega, longitude_entrega, v_destino.latitude, v_destino.longitude
      )::numeric, 2),
      transferencias = transferencias + 1
  where id = v_pedido.id;

  insert into public.transferencias_pedido (pedido_id, de_central_id, para_central_id, motivo, por_perfil_id)
  values (v_pedido.id, v_origem.id, v_destino.id, v_motivo, v_usuario);

  insert into public.historico_status (pedido_id, central_id, status, evento, observacao, por_perfil_id)
  values (
    v_pedido.id,
    v_destino.id,
    'novo',
    'transferencia',
    'Encaminhado de ' || v_origem.nome || ' para ' || v_destino.nome || '. Motivo: ' || v_motivo,
    v_usuario
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Estoque
-- ---------------------------------------------------------------------------

-- p_tipo: entrada, saida ou ajuste (somam as variações informadas)
--         contagem (define os valores contados; a variação é calculada).
create or replace function public.movimentar_estoque(
  p_central_id uuid,
  p_produto_id uuid,
  p_tipo public.tipo_movimento_estoque,
  p_cheios integer,
  p_vazios integer,
  p_motivo text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_motivo text := nullif(btrim(coalesce(p_motivo, '')), '');
  v_atual public.estoque_central%rowtype;
  v_delta_cheios integer;
  v_delta_vazios integer;
  v_cheios integer;
  v_vazios integer;
begin
  if not public.pode_acessar_central(p_central_id) then
    raise exception 'Você não tem acesso a esta central.' using errcode = '42501';
  end if;
  if p_tipo = 'entrega_pedido' then
    raise exception 'Esse tipo de movimento é registrado automaticamente na entrega.'
      using errcode = '22023';
  end if;
  if v_motivo is null then
    raise exception 'Informe o motivo do movimento.' using errcode = '22023';
  end if;
  if char_length(v_motivo) > 200 then
    raise exception 'O motivo pode ter no máximo 200 letras.' using errcode = '22023';
  end if;
  if not exists (select 1 from public.produtos where id = p_produto_id) then
    raise exception 'Produto não encontrado.' using errcode = 'P0002';
  end if;
  if abs(coalesce(p_cheios, 0)) > 100000 or abs(coalesce(p_vazios, 0)) > 100000 then
    raise exception 'Quantidade fora do limite.' using errcode = '22023';
  end if;

  insert into public.estoque_central (central_id, produto_id)
  values (p_central_id, p_produto_id)
  on conflict (central_id, produto_id) do nothing;

  select * into v_atual
  from public.estoque_central
  where central_id = p_central_id and produto_id = p_produto_id
  for update;

  if p_tipo = 'contagem' then
    if coalesce(p_cheios, 0) < 0 or coalesce(p_vazios, 0) < 0 then
      raise exception 'Na contagem, informe quantidades a partir de zero.' using errcode = '22023';
    end if;
    v_delta_cheios := coalesce(p_cheios, v_atual.cheios) - v_atual.cheios;
    v_delta_vazios := coalesce(p_vazios, v_atual.vazios) - v_atual.vazios;
  elsif p_tipo = 'entrada' then
    v_delta_cheios := abs(coalesce(p_cheios, 0));
    v_delta_vazios := -abs(coalesce(p_vazios, 0));
  elsif p_tipo = 'saida' then
    v_delta_cheios := -abs(coalesce(p_cheios, 0));
    v_delta_vazios := -abs(coalesce(p_vazios, 0));
  else
    v_delta_cheios := coalesce(p_cheios, 0);
    v_delta_vazios := coalesce(p_vazios, 0);
  end if;

  if v_delta_cheios = 0 and v_delta_vazios = 0 then
    return jsonb_build_object('cheios', v_atual.cheios, 'vazios', v_atual.vazios, 'alterado', false);
  end if;

  update public.estoque_central
  set cheios = cheios + v_delta_cheios,
      vazios = vazios + v_delta_vazios
  where central_id = p_central_id and produto_id = p_produto_id
  returning cheios, vazios into v_cheios, v_vazios;

  insert into public.movimentos_estoque (
    central_id, produto_id, tipo, delta_cheios, delta_vazios,
    cheios_apos, vazios_apos, motivo, por_perfil_id
  ) values (
    p_central_id, p_produto_id, p_tipo, v_delta_cheios, v_delta_vazios,
    v_cheios, v_vazios, v_motivo, auth.uid()
  );

  return jsonb_build_object('cheios', v_cheios, 'vazios', v_vazios, 'alterado', true);
end;
$$;

-- ---------------------------------------------------------------------------
-- Criar central (somente o dono)
-- ---------------------------------------------------------------------------

-- Se uma central modelo for informada, copia preços, janelas e faixas dela.
-- Sem modelo, cria uma faixa padrão de 10 km sem taxa e janelas de segunda a
-- sábado (8h-12h e 13h-18h, 10 pedidos cada), que a central ajusta depois.
create or replace function public.criar_central(
  p_nome text,
  p_cidade text,
  p_uf text,
  p_endereco text,
  p_latitude double precision,
  p_longitude double precision,
  p_whatsapp text default null,
  p_ativa boolean default false,
  p_central_modelo_id uuid default null
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if not public.eh_dono() then
    raise exception 'Somente o dono pode criar centrais.' using errcode = '42501';
  end if;

  if p_central_modelo_id is not null
     and not exists (select 1 from public.centrais where id = p_central_modelo_id) then
    raise exception 'Central modelo não encontrada.' using errcode = 'P0002';
  end if;

  insert into public.centrais (nome, cidade, uf, endereco, latitude, longitude, whatsapp, ativa)
  values (
    p_nome, p_cidade, upper(coalesce(p_uf, '')), coalesce(p_endereco, ''),
    p_latitude, p_longitude, p_whatsapp, coalesce(p_ativa, false)
  )
  returning id into v_id;

  if p_central_modelo_id is not null then
    insert into public.precos_central (central_id, produto_id, preco_centavos, disponivel)
    select v_id, produto_id, preco_centavos, disponivel
    from public.precos_central
    where central_id = p_central_modelo_id;

    insert into public.janelas_entrega (central_id, dia_semana, hora_inicio, hora_fim, capacidade, ativa)
    select v_id, dia_semana, hora_inicio, hora_fim, capacidade, ativa
    from public.janelas_entrega
    where central_id = p_central_modelo_id;

    insert into public.faixas_entrega (central_id, ate_km, taxa_entrega_centavos)
    select v_id, ate_km, taxa_entrega_centavos
    from public.faixas_entrega
    where central_id = p_central_modelo_id;
  end if;

  if not exists (select 1 from public.faixas_entrega where central_id = v_id) then
    insert into public.faixas_entrega (central_id, ate_km, taxa_entrega_centavos)
    values (v_id, 10, 0);
  end if;

  if not exists (select 1 from public.janelas_entrega where central_id = v_id) then
    insert into public.janelas_entrega (central_id, dia_semana, hora_inicio, hora_fim, capacidade)
    select v_id, d, h.inicio, h.fim, 10
    from generate_series(1, 6) as d
    cross join (values (time '08:00', time '12:00'), (time '13:00', time '18:00')) as h (inicio, fim);
  end if;

  insert into public.estoque_central (central_id, produto_id)
  select v_id, pc.produto_id
  from public.precos_central as pc
  where pc.central_id = v_id
  on conflict do nothing;

  return v_id;
end;
$$;
