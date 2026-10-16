-- Fase 1/5 — tempo real, fotos dos produtos, aviso de notificação e
-- permissões de execução das funções.

-- ---------------------------------------------------------------------------
-- Tempo real: a fila da central e o acompanhamento do cliente
-- ---------------------------------------------------------------------------
-- O Realtime do Supabase aplica as mesmas regras de RLS antes de entregar cada
-- mudança, então ninguém recebe pedido de outra central ou de outro cliente.

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.pedidos, public.historico_status;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Fotos dos produtos (Storage)
-- ---------------------------------------------------------------------------
-- Bucket público para leitura (fotos de catálogo); só o dono envia ou troca.
-- Limite de 2 MB e apenas imagens. Não há permissão para apagar pelo app
-- (menor privilégio): a foto antiga deixa de ser usada quando o produto recebe
-- outra, e a limpeza de arquivos sem uso é feita pela manutenção do servidor.

do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'storage') then
    insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    values ('produtos', 'produtos', true, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
    on conflict (id) do update
    set public = excluded.public,
        file_size_limit = excluded.file_size_limit,
        allowed_mime_types = excluded.allowed_mime_types;

    execute $p$
      create policy produtos_fotos_inserir_dono on storage.objects
      for insert to authenticated
      with check (bucket_id = 'produtos' and (select public.eh_dono()))
    $p$;
    execute $p$
      create policy produtos_fotos_atualizar_dono on storage.objects
      for update to authenticated
      using (bucket_id = 'produtos' and (select public.eh_dono()))
      with check (bucket_id = 'produtos' and (select public.eh_dono()))
    $p$;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Aviso para a função de notificações
-- ---------------------------------------------------------------------------
-- A cada evento do pedido, o banco chama a Edge Function "notificar" (pelo
-- pg_net, sem travar o pedido). Endereço e segredo ficam no Vault com os nomes
-- notificar_url e notificar_segredo. Sem essa configuração nada é enviado, e
-- qualquer falha aqui vira só um aviso no log: o pedido nunca é bloqueado.

do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_net') then
    create extension if not exists pg_net;
  end if;
end;
$$;

create or replace function public.tg_avisar_evento_pedido()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url text;
  v_segredo text;
begin
  begin
    execute 'select decrypted_secret from vault.decrypted_secrets where name = $1 limit 1'
      into v_url using 'notificar_url';
    execute 'select decrypted_secret from vault.decrypted_secrets where name = $1 limit 1'
      into v_segredo using 'notificar_segredo';

    if v_url is not null and v_segredo is not null then
      execute 'select net.http_post(url := $1, body := $2, headers := $3, timeout_milliseconds := 5000)'
      using
        v_url,
        jsonb_build_object(
          'historico_id', new.id,
          'pedido_id', new.pedido_id,
          'central_id', new.central_id,
          'status', new.status,
          'evento', new.evento
        ),
        jsonb_build_object(
          'Content-Type', 'application/json',
          'x-segredo-notificacao', v_segredo
        );
    end if;
  exception when others then
    raise warning 'Aviso de notificação não enviado: %', sqlerrm;
  end;
  return null;
end;
$$;

create trigger avisar_evento_pedido
after insert on public.historico_status
for each row execute function public.tg_avisar_evento_pedido();

-- ---------------------------------------------------------------------------
-- Permissões de execução
-- ---------------------------------------------------------------------------
-- Nenhuma função fica aberta por padrão. Só as listadas abaixo podem ser
-- chamadas por quem está logado; o anônimo não chama nenhuma. Migrations
-- seguintes que criam funções fazem as próprias permissões.

do $$
declare
  v_funcao record;
begin
  for v_funcao in
    select p.oid::regprocedure as assinatura
    from pg_proc as p
    join pg_namespace as n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prokind = 'f'
  loop
    execute format('revoke all on function %s from public, anon, authenticated', v_funcao.assinatura);
    execute format('grant execute on function %s to service_role', v_funcao.assinatura);
  end loop;
end;
$$;

-- Usadas pelas políticas de RLS.
grant execute on function public.eh_dono() to authenticated;
grant execute on function public.central_do_operador() to authenticated;
grant execute on function public.pode_acessar_central(uuid) to authenticated;
grant execute on function public.eh_cliente_ativo() to authenticated;

-- Utilitárias, sem dados.
grant execute on function public.distancia_km(double precision, double precision, double precision, double precision) to authenticated;
grant execute on function public.hoje_local() to authenticated;
grant execute on function public.agora_local() to authenticated;
-- Usada pelos gatilhos que limpam telefone, CEP e WhatsApp digitados.
grant execute on function public.somente_digitos(text, integer) to authenticated;

-- Funções de negócio (cada uma confere quem chamou).
grant execute on function public.atendimento_para_coordenadas(double precision, double precision) to authenticated;
grant execute on function public.atendimento_para_endereco(uuid) to authenticated;
grant execute on function public.agenda_disponivel(uuid, integer) to authenticated;
grant execute on function public.criar_pedido(uuid, date, uuid, public.forma_pagamento, jsonb, uuid, integer, text) to authenticated;
grant execute on function public.mudar_status_pedido(uuid, public.status_pedido, text) to authenticated;
grant execute on function public.atribuir_entregador(uuid, uuid) to authenticated;
grant execute on function public.opcoes_transferencia(uuid) to authenticated;
grant execute on function public.transferir_pedido(uuid, uuid, text) to authenticated;
grant execute on function public.movimentar_estoque(uuid, uuid, public.tipo_movimento_estoque, integer, integer, text) to authenticated;
grant execute on function public.criar_central(text, text, text, text, double precision, double precision, text, boolean, uuid) to authenticated;
grant execute on function public.resumo_centrais(date, date, uuid) to authenticated;
grant execute on function public.relatorio_produtos(date, date, uuid) to authenticated;
grant execute on function public.relatorio_por_dia(date, date, uuid) to authenticated;
