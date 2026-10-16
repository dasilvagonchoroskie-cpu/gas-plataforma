-- Fase 5 (preparada junto com o banco) — relatórios.
--
-- Datas consideradas: dia do pedido no fuso America/Sao_Paulo.
-- Faturamento: soma dos pedidos entregues.
-- O dono vê qualquer central (ou todas, com p_central_id nulo); o operador vê
-- somente a própria central, qualquer que seja o filtro enviado.

create or replace function public.escopo_relatorio(p_central_id uuid)
returns uuid[]
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_operador uuid;
begin
  if public.eh_dono() then
    if p_central_id is null then
      return array(select id from public.centrais);
    end if;
    return array[p_central_id];
  end if;

  v_operador := public.central_do_operador();
  if v_operador is null then
    raise exception 'Você não tem acesso aos relatórios.' using errcode = '42501';
  end if;
  if p_central_id is not null and p_central_id <> v_operador then
    raise exception 'Você só pode ver os relatórios da sua central.' using errcode = '42501';
  end if;
  return array[v_operador];
end;
$$;

create or replace function public.validar_periodo(p_inicio date, p_fim date)
returns void
language plpgsql
immutable
set search_path = ''
as $$
begin
  if p_inicio is null or p_fim is null or p_fim < p_inicio then
    raise exception 'Período inválido.' using errcode = '22023';
  end if;
  if p_fim - p_inicio > 366 then
    raise exception 'Escolha um período de até um ano.' using errcode = '22023';
  end if;
end;
$$;

-- Um resumo por central: pedidos, entregues, cancelados, em aberto e faturamento.
create or replace function public.resumo_centrais(
  p_inicio date,
  p_fim date,
  p_central_id uuid default null
)
returns table (
  central_id uuid,
  central_nome text,
  cidade text,
  ativa boolean,
  pedidos integer,
  entregues integer,
  cancelados integer,
  em_aberto integer,
  faturamento_centavos bigint,
  ticket_medio_centavos bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_escopo uuid[];
begin
  perform public.validar_periodo(p_inicio, p_fim);
  v_escopo := public.escopo_relatorio(p_central_id);

  return query
  select
    c.id,
    c.nome,
    c.cidade,
    c.ativa,
    count(p.id)::integer,
    count(p.id) filter (where p.status = 'entregue')::integer,
    count(p.id) filter (where p.status = 'cancelado')::integer,
    count(p.id) filter (where p.status in ('novo', 'confirmado', 'em_rota'))::integer,
    coalesce(sum(p.total_centavos) filter (where p.status = 'entregue'), 0)::bigint,
    coalesce(
      (sum(p.total_centavos) filter (where p.status = 'entregue'))
        / nullif(count(p.id) filter (where p.status = 'entregue'), 0),
      0
    )::bigint
  from public.centrais as c
  left join public.pedidos as p
    on p.central_id = c.id
   and (p.criado_em at time zone 'America/Sao_Paulo')::date between p_inicio and p_fim
  where c.id = any (v_escopo)
  group by c.id, c.nome, c.cidade, c.ativa
  order by c.nome;
end;
$$;

-- Quantidade e valor vendidos por produto (pedidos entregues).
create or replace function public.relatorio_produtos(
  p_inicio date,
  p_fim date,
  p_central_id uuid default null
)
returns table (
  produto_id uuid,
  produto_nome text,
  quantidade bigint,
  valor_centavos bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_escopo uuid[];
begin
  perform public.validar_periodo(p_inicio, p_fim);
  v_escopo := public.escopo_relatorio(p_central_id);

  return query
  select
    ip.produto_id,
    max(ip.produto_nome),
    sum(ip.quantidade)::bigint,
    sum(ip.quantidade::bigint * ip.preco_unitario_centavos)::bigint
  from public.itens_pedido as ip
  join public.pedidos as p on p.id = ip.pedido_id
  where p.central_id = any (v_escopo)
    and p.status = 'entregue'
    and (p.criado_em at time zone 'America/Sao_Paulo')::date between p_inicio and p_fim
  group by ip.produto_id
  order by 4 desc;
end;
$$;

-- Evolução dia a dia.
create or replace function public.relatorio_por_dia(
  p_inicio date,
  p_fim date,
  p_central_id uuid default null
)
returns table (
  dia date,
  pedidos integer,
  entregues integer,
  cancelados integer,
  faturamento_centavos bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_escopo uuid[];
begin
  perform public.validar_periodo(p_inicio, p_fim);
  v_escopo := public.escopo_relatorio(p_central_id);

  return query
  select
    d.dia::date,
    count(p.id)::integer,
    count(p.id) filter (where p.status = 'entregue')::integer,
    count(p.id) filter (where p.status = 'cancelado')::integer,
    coalesce(sum(p.total_centavos) filter (where p.status = 'entregue'), 0)::bigint
  from generate_series(p_inicio::timestamp, p_fim::timestamp, interval '1 day') as d (dia)
  left join public.pedidos as p
    on p.central_id = any (v_escopo)
   and (p.criado_em at time zone 'America/Sao_Paulo')::date = d.dia::date
  group by d.dia
  order by d.dia;
end;
$$;
