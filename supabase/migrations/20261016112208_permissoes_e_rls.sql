-- Fase 1 — permissões e RLS.
--
-- Princípio: negado por padrão. Ninguém sem login (anon) acessa tabela alguma.
-- Usuários logados recebem só os privilégios mínimos de cada tabela, e a RLS
-- decide linha por linha. Operações que mexem em várias tabelas (pedido,
-- status, estoque, transferência, criação de central) acontecem somente pelas
-- funções do banco, nunca por escrita direta.
--
-- Nas políticas, as chamadas a auth.uid() e às funções auxiliares ficam dentro
-- de (select ...) para o Postgres calcular uma vez por consulta, não por linha.

-- Tabelas futuras não recebem acesso automático: cada migration concede o seu.
alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;

revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
grant usage on schema public to authenticated;

-- service_role (somente servidor) mantém acesso completo para as Edge Functions.
grant all on all tables in schema public to service_role;
grant all on all sequences in schema public to service_role;

-- Privilégios mínimos para quem está logado.
grant select on
  public.perfis,
  public.centrais,
  public.operadores_central,
  public.entregadores,
  public.faixas_entrega,
  public.produtos,
  public.precos_central,
  public.estoque_central,
  public.janelas_entrega,
  public.bloqueios_agenda,
  public.enderecos,
  public.pedidos,
  public.itens_pedido,
  public.historico_status,
  public.transferencias_pedido,
  public.movimentos_estoque,
  public.dispositivos_push,
  public.auditoria
to authenticated;

-- O próprio usuário altera só nome e telefone; nunca papel, ativo ou e-mail.
grant update (nome, telefone) on public.perfis to authenticated;
grant update (nome, cidade, uf, endereco, latitude, longitude, whatsapp, ativa)
  on public.centrais to authenticated;
grant insert (central_id, nome, telefone, ativo), update (nome, telefone, ativo)
  on public.entregadores to authenticated;
grant insert (central_id, ate_km, taxa_entrega_centavos),
  update (ate_km, taxa_entrega_centavos),
  delete
  on public.faixas_entrega to authenticated;
grant insert (nome, categoria, descricao, foto_url, troca_vasilhame, ordem, ativo),
  update (nome, categoria, descricao, foto_url, troca_vasilhame, ordem, ativo)
  on public.produtos to authenticated;
grant insert (central_id, produto_id, preco_centavos, disponivel),
  update (preco_centavos, disponivel),
  delete
  on public.precos_central to authenticated;
-- Quantidades de estoque mudam só pelas funções; aqui só o alerta mínimo.
grant update (alerta_minimo) on public.estoque_central to authenticated;
grant insert (central_id, dia_semana, hora_inicio, hora_fim, capacidade, ativa),
  update (hora_inicio, hora_fim, capacidade, ativa)
  on public.janelas_entrega to authenticated;
grant insert (central_id, data, janela_id, motivo), delete
  on public.bloqueios_agenda to authenticated;
grant insert (cliente_id, apelido, cep, logradouro, numero, bairro, cidade, uf,
              complemento, referencia, latitude, longitude),
  update (apelido, cep, logradouro, numero, bairro, cidade, uf,
          complemento, referencia, latitude, longitude),
  delete
  on public.enderecos to authenticated;
grant delete on public.dispositivos_push to authenticated;

-- RLS ligada em todas as tabelas: sem política, sem acesso.
alter table public.perfis enable row level security;
alter table public.centrais enable row level security;
alter table public.operadores_central enable row level security;
alter table public.entregadores enable row level security;
alter table public.faixas_entrega enable row level security;
alter table public.produtos enable row level security;
alter table public.precos_central enable row level security;
alter table public.estoque_central enable row level security;
alter table public.janelas_entrega enable row level security;
alter table public.bloqueios_agenda enable row level security;
alter table public.enderecos enable row level security;
alter table public.pedidos enable row level security;
alter table public.itens_pedido enable row level security;
alter table public.historico_status enable row level security;
alter table public.transferencias_pedido enable row level security;
alter table public.movimentos_estoque enable row level security;
alter table public.dispositivos_push enable row level security;
alter table public.auditoria enable row level security;

-- Perfis: cada um vê o próprio; o dono vê todos.
create policy perfis_ler on public.perfis
for select to authenticated
using (id = (select auth.uid()) or (select public.eh_dono()));

create policy perfis_atualizar_proprio on public.perfis
for update to authenticated
using (id = (select auth.uid()) and excluido_em is null)
with check (id = (select auth.uid()));

-- Centrais: o cliente vê as ativas (nome, cidade e WhatsApp para falar com
-- ela); operador vê a própria; dono vê e altera todas. Criar central é só pela
-- função criar_central.
create policy centrais_ler on public.centrais
for select to authenticated
using (
  ativa
  or (select public.eh_dono())
  or id = (select public.central_do_operador())
);

create policy centrais_atualizar_dono on public.centrais
for update to authenticated
using ((select public.eh_dono()))
with check ((select public.eh_dono()));

-- Vínculos de operador: cada operador vê o próprio; dono vê todos. Mudanças
-- só pelo servidor (admin-usuarios).
create policy operadores_central_ler on public.operadores_central
for select to authenticated
using (perfil_id = (select auth.uid()) or (select public.eh_dono()));

-- Entregadores: a central cuida dos seus; o dono de todos.
create policy entregadores_ler on public.entregadores
for select to authenticated
using ((select public.eh_dono()) or central_id = (select public.central_do_operador()));

create policy entregadores_inserir on public.entregadores
for insert to authenticated
with check ((select public.eh_dono()) or central_id = (select public.central_do_operador()));

create policy entregadores_atualizar on public.entregadores
for update to authenticated
using ((select public.eh_dono()) or central_id = (select public.central_do_operador()))
with check ((select public.eh_dono()) or central_id = (select public.central_do_operador()));

-- Faixas de entrega (alcance e taxa): a central consulta; só o dono altera.
create policy faixas_entrega_ler on public.faixas_entrega
for select to authenticated
using ((select public.eh_dono()) or central_id = (select public.central_do_operador()));

create policy faixas_entrega_inserir_dono on public.faixas_entrega
for insert to authenticated
with check ((select public.eh_dono()));

create policy faixas_entrega_atualizar_dono on public.faixas_entrega
for update to authenticated
using ((select public.eh_dono()))
with check ((select public.eh_dono()));

create policy faixas_entrega_excluir_dono on public.faixas_entrega
for delete to authenticated
using ((select public.eh_dono()));

-- Produtos: todos os logados veem os ativos; dono vê e altera todos.
create policy produtos_ler on public.produtos
for select to authenticated
using (ativo or (select public.eh_dono()));

create policy produtos_inserir_dono on public.produtos
for insert to authenticated
with check ((select public.eh_dono()));

create policy produtos_atualizar_dono on public.produtos
for update to authenticated
using ((select public.eh_dono()))
with check ((select public.eh_dono()));

-- Preços: cliente vê os disponíveis de centrais ativas; operador vê os da
-- própria central e pode marcar disponível/indisponível (o valor é protegido
-- por gatilho); dono faz tudo.
create policy precos_central_ler on public.precos_central
for select to authenticated
using (
  (select public.eh_dono())
  or central_id = (select public.central_do_operador())
  or (
    disponivel
    and exists (select 1 from public.centrais as c where c.id = central_id and c.ativa)
    and exists (select 1 from public.produtos as pr where pr.id = produto_id and pr.ativo)
  )
);

create policy precos_central_inserir_dono on public.precos_central
for insert to authenticated
with check ((select public.eh_dono()));

create policy precos_central_atualizar on public.precos_central
for update to authenticated
using ((select public.eh_dono()) or central_id = (select public.central_do_operador()))
with check ((select public.eh_dono()) or central_id = (select public.central_do_operador()));

create policy precos_central_excluir_dono on public.precos_central
for delete to authenticated
using ((select public.eh_dono()));

-- Estoque: só a central dona e o dono.
create policy estoque_central_ler on public.estoque_central
for select to authenticated
using ((select public.eh_dono()) or central_id = (select public.central_do_operador()));

create policy estoque_central_atualizar on public.estoque_central
for update to authenticated
using ((select public.eh_dono()) or central_id = (select public.central_do_operador()))
with check ((select public.eh_dono()) or central_id = (select public.central_do_operador()));

create policy movimentos_estoque_ler on public.movimentos_estoque
for select to authenticated
using ((select public.eh_dono()) or central_id = (select public.central_do_operador()));

-- Janelas e bloqueios: a central administra a própria agenda. O cliente
-- consulta horários livres pela função agenda_disponivel.
create policy janelas_entrega_ler on public.janelas_entrega
for select to authenticated
using ((select public.eh_dono()) or central_id = (select public.central_do_operador()));

create policy janelas_entrega_inserir on public.janelas_entrega
for insert to authenticated
with check ((select public.eh_dono()) or central_id = (select public.central_do_operador()));

create policy janelas_entrega_atualizar on public.janelas_entrega
for update to authenticated
using ((select public.eh_dono()) or central_id = (select public.central_do_operador()))
with check ((select public.eh_dono()) or central_id = (select public.central_do_operador()));

create policy bloqueios_agenda_ler on public.bloqueios_agenda
for select to authenticated
using ((select public.eh_dono()) or central_id = (select public.central_do_operador()));

create policy bloqueios_agenda_inserir on public.bloqueios_agenda
for insert to authenticated
with check ((select public.eh_dono()) or central_id = (select public.central_do_operador()));

create policy bloqueios_agenda_excluir on public.bloqueios_agenda
for delete to authenticated
using ((select public.eh_dono()) or central_id = (select public.central_do_operador()));

-- Endereços: só o próprio cliente. A central recebe a cópia dentro do pedido.
create policy enderecos_ler_proprio on public.enderecos
for select to authenticated
using (cliente_id = (select auth.uid()));

create policy enderecos_inserir_proprio on public.enderecos
for insert to authenticated
with check (cliente_id = (select auth.uid()) and (select public.eh_cliente_ativo()));

create policy enderecos_atualizar_proprio on public.enderecos
for update to authenticated
using (cliente_id = (select auth.uid()))
with check (cliente_id = (select auth.uid()));

create policy enderecos_excluir_proprio on public.enderecos
for delete to authenticated
using (cliente_id = (select auth.uid()));

-- Pedidos: o cliente vê os próprios; a central vê os que estão com ela; o dono
-- vê todos. Nenhuma escrita direta: tudo passa pelas funções.
create policy pedidos_ler on public.pedidos
for select to authenticated
using (
  cliente_id = (select auth.uid())
  or (select public.eh_dono())
  or central_id = (select public.central_do_operador())
);

create policy itens_pedido_ler on public.itens_pedido
for select to authenticated
using (
  exists (
    select 1 from public.pedidos as p
    where p.id = pedido_id
      and (
        p.cliente_id = (select auth.uid())
        or (select public.eh_dono())
        or p.central_id = (select public.central_do_operador())
      )
  )
);

create policy historico_status_ler on public.historico_status
for select to authenticated
using (
  exists (
    select 1 from public.pedidos as p
    where p.id = pedido_id
      and (
        p.cliente_id = (select auth.uid())
        or (select public.eh_dono())
        or p.central_id = (select public.central_do_operador())
      )
  )
);

-- A central que enviou ou recebeu a transferência vê o registro.
create policy transferencias_pedido_ler on public.transferencias_pedido
for select to authenticated
using (
  (select public.eh_dono())
  or de_central_id = (select public.central_do_operador())
  or para_central_id = (select public.central_do_operador())
);

-- Aparelhos para notificação: cada um vê e remove os próprios. O registro é
-- feito pela função registrar_dispositivo.
create policy dispositivos_push_ler_proprio on public.dispositivos_push
for select to authenticated
using (perfil_id = (select auth.uid()));

create policy dispositivos_push_excluir_proprio on public.dispositivos_push
for delete to authenticated
using (perfil_id = (select auth.uid()));

-- Auditoria: somente o dono consulta. Ninguém escreve diretamente.
create policy auditoria_ler_dono on public.auditoria
for select to authenticated
using ((select public.eh_dono()));
