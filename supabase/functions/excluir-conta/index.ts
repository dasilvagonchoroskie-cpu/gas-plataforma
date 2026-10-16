// Exclusão da conta pelo próprio cliente (exigida pelas lojas e pela LGPD).
//
// 1. Confere as regras e anonimiza o perfil e os pedidos (função do banco,
//    chamada como o próprio usuário: pedido em andamento ou fiado em aberto
//    impedem a exclusão).
// 2. Apaga a ficha de cadastro, os endereços, os aparelhos e as fotos da ficha.
// 3. Apaga o login.
//
// Pode ser chamada de novo se algo falhar no meio: cada passo é repetível.
import { createClient } from "npm:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function resposta(status: number, corpo: Record<string, unknown>): Response {
  return new Response(JSON.stringify(corpo), {
    status,
    headers: { ...CORS, "Content-Type": "application/json; charset=utf-8" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  if (req.method !== "POST") return resposta(405, { erro: "Método não permitido." });

  const url = Deno.env.get("SUPABASE_URL")!;
  const autorizacao = req.headers.get("Authorization") ?? "";
  const token = autorizacao.replace(/^Bearer\s+/i, "");
  if (!token) return resposta(401, { erro: "Faça login novamente." });

  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: usuario, error: erroUsuario } = await admin.auth.getUser(token);
  if (erroUsuario || !usuario?.user) return resposta(401, { erro: "Faça login novamente." });
  const id = usuario.user.id;

  // Cliente com o token do próprio usuário: as regras do banco valem para ele.
  const comoUsuario = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });

  const { error: erroAnonimizar } = await comoUsuario.rpc("anonimizar_minha_conta");
  if (erroAnonimizar) {
    return resposta(400, { erro: erroAnonimizar.message || "Não foi possível excluir a conta." });
  }

  // Dados pessoais que não ficam nem anonimizados: são apagados.
  for (const [tabela, coluna] of [
    ["fichas_cliente", "cliente_id"],
    ["enderecos", "cliente_id"],
    ["dispositivos_push", "perfil_id"],
  ] as const) {
    const { error } = await admin.from(tabela).delete().eq(coluna, id);
    if (error) {
      console.error(`excluir-conta: falha ao apagar ${tabela}:`, error.message);
      return resposta(500, { erro: "Não foi possível apagar todos os seus dados agora. Tente de novo." });
    }
  }

  // Fotos da ficha (pasta do cliente no bucket privado).
  const { data: fotos, error: erroLista } = await admin.storage.from("fichas").list(id, { limit: 100 });
  if (erroLista) {
    console.error("excluir-conta: falha ao listar fotos:", erroLista.message);
    return resposta(500, { erro: "Não foi possível apagar todos os seus dados agora. Tente de novo." });
  }
  if (fotos && fotos.length > 0) {
    const { error: erroFotos } = await admin.storage.from("fichas").remove(fotos.map((f) => `${id}/${f.name}`));
    if (erroFotos) {
      console.error("excluir-conta: falha ao apagar fotos:", erroFotos.message);
      return resposta(500, { erro: "Não foi possível apagar todos os seus dados agora. Tente de novo." });
    }
  }

  const { error: erroExcluir } = await admin.auth.admin.deleteUser(id);
  if (erroExcluir) {
    console.error("Falha ao apagar login:", erroExcluir.message);
    return resposta(500, { erro: "Seus dados foram removidos, mas o login não foi apagado. Tente de novo." });
  }

  return resposta(200, { ok: true });
});
