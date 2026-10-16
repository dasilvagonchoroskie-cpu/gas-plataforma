// Configuração das notificações push pelo dono, na Super Central.
//
// O dono baixa no console do Firebase o arquivo da "conta de serviço" e o envia
// pelo app. Esta função confere que é o dono, valida o arquivo pedindo um
// acesso ao Google com ele e guarda no Vault (função guardar_segredo_do_servidor).
// O conteúdo nunca volta para o app: só o nome do projeto e a conta.
//
// Ações (só o dono):
//   { "acao": "situacao" }                  → { configurado, projeto, conta }
//   { "acao": "guardar", "arquivo": "..." } → valida e guarda
//   { "acao": "testar" }                    → envia um aviso de teste para os
//                                             aparelhos do próprio dono
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const NOME_SEGREDO = "fcm_conta_servico";
const TAMANHO_MAXIMO = 20000;

type ContaServico = { type?: string; project_id?: string; client_email?: string; private_key?: string };

function resposta(status: number, corpo: Record<string, unknown>): Response {
  return new Response(JSON.stringify(corpo), {
    status,
    headers: { ...CORS, "Content-Type": "application/json; charset=utf-8" },
  });
}

function base64Url(bytes: ArrayBuffer | Uint8Array): string {
  const arr = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  let bin = "";
  for (const b of arr) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/** Confere o arquivo pedindo um acesso de envio de push ao Google. */
async function conferirComGoogle(conta: Required<Pick<ContaServico, "client_email" | "private_key">>) {
  const agora = Math.floor(Date.now() / 1000);
  const cabecalho = base64Url(new TextEncoder().encode(JSON.stringify({ alg: "RS256", typ: "JWT" })));
  const carga = base64Url(new TextEncoder().encode(JSON.stringify({
    iss: conta.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: agora,
    exp: agora + 600,
  })));
  const pem = conta.private_key.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const chave = await crypto.subtle.importKey(
    "pkcs8",
    Uint8Array.from(atob(pem), (c) => c.charCodeAt(0)),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const assinatura = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    chave,
    new TextEncoder().encode(`${cabecalho}.${carga}`),
  );
  const r = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${cabecalho}.${carga}.${base64Url(assinatura)}`,
    }),
  });
  if (!r.ok) throw new Error(`Google recusou a chave (HTTP ${r.status})`);
}

function lerConta(texto: string): ContaServico | null {
  try {
    const conta = JSON.parse(texto) as ContaServico;
    return conta && typeof conta === "object" ? conta : null;
  } catch {
    return null;
  }
}

async function situacao(admin: SupabaseClient): Promise<Record<string, unknown>> {
  const { data, error } = await admin.rpc("segredo_do_servidor", { p_nome: NOME_SEGREDO });
  if (error) throw error;
  const conta = typeof data === "string" ? lerConta(data) : null;
  return {
    configurado: !!conta?.project_id,
    projeto: conta?.project_id ?? null,
    conta: conta?.client_email ?? null,
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  if (req.method !== "POST") return resposta(405, { erro: "Método não permitido." });

  const url = Deno.env.get("SUPABASE_URL")!;
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const { data: usuario } = token ? await admin.auth.getUser(token) : { data: null };
  if (!usuario?.user) return resposta(401, { erro: "Faça login novamente." });

  const { data: perfil } = await admin
    .from("perfis")
    .select("papel, ativo")
    .eq("id", usuario.user.id)
    .maybeSingle();
  if (!perfil || perfil.papel !== "dono" || !perfil.ativo) {
    return resposta(403, { erro: "Só o dono da revenda configura as notificações." });
  }

  const corpo = await req.json().catch(() => ({})) as Record<string, unknown>;
  const acao = typeof corpo.acao === "string" ? corpo.acao : "";

  try {
    if (acao === "situacao") {
      return resposta(200, await situacao(admin));
    }

    if (acao === "guardar") {
      const arquivo = typeof corpo.arquivo === "string" ? corpo.arquivo.trim() : "";
      if (!arquivo || arquivo.length > TAMANHO_MAXIMO) {
        return resposta(400, { erro: "Arquivo vazio ou grande demais. Envie o arquivo .json da chave." });
      }
      const conta = lerConta(arquivo);
      const valida = conta?.type === "service_account" && !!conta.project_id &&
        !!conta.client_email?.endsWith(".iam.gserviceaccount.com") &&
        !!conta.private_key?.includes("PRIVATE KEY");
      if (!conta || !valida) {
        return resposta(400, {
          erro: "Este arquivo não é a chave da conta de serviço do Firebase. No Firebase, abra " +
            "Configurações do projeto → Contas de serviço → Gerar nova chave privada.",
        });
      }
      try {
        await conferirComGoogle({ client_email: conta.client_email!, private_key: conta.private_key! });
      } catch (erro) {
        console.warn("configurar-notificacoes:", String(erro));
        return resposta(400, {
          erro: "O Google não aceitou esta chave. Gere uma chave nova no Firebase e envie de novo.",
        });
      }
      // Guarda só os campos necessários para enviar push.
      const essencial = JSON.stringify({
        type: conta.type,
        project_id: conta.project_id,
        client_email: conta.client_email,
        private_key: conta.private_key,
      });
      const { error } = await admin.rpc("guardar_segredo_do_servidor", {
        p_nome: NOME_SEGREDO,
        p_valor: essencial,
        p_por_perfil_id: usuario.user.id,
      });
      if (error) throw error;
      return resposta(200, await situacao(admin));
    }

    if (acao === "testar") {
      const { data: segredo, error } = await admin.rpc("segredo_do_servidor", { p_nome: "notificar_segredo" });
      if (error || typeof segredo !== "string" || !segredo) throw error ?? new Error("sem segredo do aviso");
      const r = await fetch(`${url}/functions/v1/notificar`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-segredo-notificacao": segredo },
        body: JSON.stringify({ evento: "teste", perfil_id: usuario.user.id }),
      });
      const resultado = await r.json().catch(() => ({})) as Record<string, unknown>;
      return resposta(200, {
        enviado: resultado.enviado === true,
        quantidade: Number(resultado.quantidade ?? 0),
        motivo: resultado.motivo ?? null,
      });
    }

    return resposta(400, { erro: "Ação desconhecida." });
  } catch (erro) {
    console.error("configurar-notificacoes:", acao, String(erro));
    return resposta(500, { erro: "Não foi possível concluir agora. Tente de novo." });
  }
});
