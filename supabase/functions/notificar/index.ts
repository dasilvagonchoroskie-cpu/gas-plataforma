// Notificações push (Firebase Cloud Messaging) a cada evento do pedido.
//
// Quem chama é o próprio banco (gatilho em historico_status, via pg_net), com o
// cabeçalho x-segredo-notificacao, conferido com o segredo notificar_segredo do
// Vault (lido pela função segredo_do_servidor, só com a chave service_role).
// Segredo da função (cadastrado no painel do Supabase, nunca no código):
//   FCM_CONTA_SERVICO  — JSON da conta de serviço do Firebase (só envio de push)
// Sem FCM_CONTA_SERVICO a função responde "sem configuração" e nada é enviado.
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

type ContaServico = { project_id: string; client_email: string; private_key: string };
type Evento = { pedido_id?: string; status?: string; evento?: string; central_id?: string };
type Mensagem = { titulo: string; corpo: string };

function resposta(status: number, corpo: Record<string, unknown>): Response {
  return new Response(JSON.stringify(corpo), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });
}

function iguaisSemVazarTempo(a: string, b: string): boolean {
  const ca = new TextEncoder().encode(a);
  const cb = new TextEncoder().encode(b);
  let diferenca = ca.length ^ cb.length;
  for (let i = 0; i < Math.max(ca.length, cb.length); i++) {
    diferenca |= (ca[i] ?? 0) ^ (cb[i] ?? 0);
  }
  return diferenca === 0;
}

function base64Url(bytes: ArrayBuffer | Uint8Array): string {
  const arr = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  let bin = "";
  for (const b of arr) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

let tokenEmCache: { valor: string; expiraEm: number } | null = null;
let segredoEmCache: { valor: string; lidoEm: number } | null = null;

/** Segredo esperado no cabeçalho, guardado no Vault (cache de 5 minutos). */
async function segredoEsperado(admin: SupabaseClient): Promise<string> {
  if (segredoEmCache && Date.now() - segredoEmCache.lidoEm < 5 * 60 * 1000) return segredoEmCache.valor;
  const { data, error } = await admin.rpc("segredo_do_servidor", { p_nome: "notificar_segredo" });
  if (error) {
    console.error("notificar: não foi possível ler o segredo:", error.message);
    return "";
  }
  const valor = typeof data === "string" ? data : "";
  segredoEmCache = { valor, lidoEm: Date.now() };
  return valor;
}

async function tokenGoogle(conta: ContaServico): Promise<string> {
  const agora = Math.floor(Date.now() / 1000);
  if (tokenEmCache && tokenEmCache.expiraEm - 60 > agora) return tokenEmCache.valor;

  const cabecalho = base64Url(new TextEncoder().encode(JSON.stringify({ alg: "RS256", typ: "JWT" })));
  const carga = base64Url(new TextEncoder().encode(JSON.stringify({
    iss: conta.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: agora,
    exp: agora + 3600,
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
  if (!r.ok) throw new Error(`Token Google: HTTP ${r.status}`);
  const corpo = await r.json();
  tokenEmCache = { valor: corpo.access_token, expiraEm: agora + Number(corpo.expires_in ?? 3600) };
  return tokenEmCache.valor;
}

async function tokensDe(admin: SupabaseClient, perfis: string[]): Promise<string[]> {
  if (perfis.length === 0) return [];
  const { data, error } = await admin.from("dispositivos_push").select("token").in("perfil_id", perfis);
  if (error) throw error;
  return (data ?? []).map((d) => d.token as string);
}

async function enviar(
  admin: SupabaseClient,
  conta: ContaServico,
  tokens: string[],
  mensagem: Mensagem,
  dados: Record<string, string>,
  canal: string,
): Promise<number> {
  let enviados = 0;
  const acesso = await tokenGoogle(conta);
  for (const token of tokens) {
    const r = await fetch(`https://fcm.googleapis.com/v1/projects/${conta.project_id}/messages:send`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${acesso}` },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: mensagem.titulo, body: mensagem.corpo },
          data: dados,
          android: { priority: "HIGH", notification: { channel_id: canal, sound: "default" } },
          apns: { payload: { aps: { sound: "default" } } },
        },
      }),
    });
    if (r.ok) {
      enviados++;
    } else if (r.status === 404 || r.status === 400) {
      // Aparelho desinstalou o app ou o token expirou: remove para não insistir.
      const erro = await r.text();
      if (erro.includes("UNREGISTERED") || erro.includes("INVALID_ARGUMENT")) {
        await admin.from("dispositivos_push").delete().eq("token", token);
      }
    } else {
      console.error("FCM:", r.status, await r.text());
    }
  }
  return enviados;
}

function mensagemParaCliente(numero: number, status: string, evento: string, observacao: string, central: string): Mensagem | null {
  if (evento === "transferencia") {
    return { titulo: `Pedido nº ${numero} encaminhado`, corpo: `A ${central} vai fazer a sua entrega.` };
  }
  if (evento !== "status") return null;
  switch (status) {
    case "confirmado":
      return observacao.includes("voltou")
        ? { titulo: `Pedido nº ${numero}`, corpo: "Seu pedido voltou para a central e sai de novo em breve." }
        : { titulo: `Pedido nº ${numero} confirmado`, corpo: "A central já está separando o seu pedido." };
    case "em_rota":
      return { titulo: "Seu pedido saiu para entrega", corpo: "O entregador está a caminho." };
    case "entregue":
      return { titulo: "Pedido entregue", corpo: "Obrigado pela preferência!" };
    case "cancelado":
      return { titulo: `Pedido nº ${numero} cancelado`, corpo: observacao || "Fale com a central se tiver dúvidas." };
    default:
      return null;
  }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return resposta(405, { erro: "Método não permitido." });

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const segredo = await segredoEsperado(admin);
  const recebido = req.headers.get("x-segredo-notificacao") ?? "";
  if (!segredo || !iguaisSemVazarTempo(segredo, recebido)) {
    return resposta(401, { erro: "Não autorizado." });
  }

  const contaTexto = Deno.env.get("FCM_CONTA_SERVICO");
  if (!contaTexto) return resposta(200, { enviado: false, motivo: "sem configuração do Firebase" });

  let conta: ContaServico;
  try {
    conta = JSON.parse(contaTexto);
  } catch {
    console.error("FCM_CONTA_SERVICO não é um JSON válido.");
    return resposta(200, { enviado: false, motivo: "configuração inválida" });
  }

  const evento = await req.json().catch(() => ({})) as Evento;
  if (!evento.pedido_id) return resposta(400, { erro: "Evento sem pedido." });

  const { data: pedido, error } = await admin
    .from("pedidos")
    .select("id, numero, cliente_id, central_id, status, data_entrega, hora_inicio, hora_fim, centrais(nome)")
    .eq("id", evento.pedido_id)
    .maybeSingle();
  if (error) {
    console.error("notificar:", error.message);
    return resposta(500, { erro: "Falha ao ler o pedido." });
  }
  if (!pedido) return resposta(200, { enviado: false, motivo: "pedido não encontrado" });

  const { data: ultimo } = await admin
    .from("historico_status")
    .select("observacao")
    .eq("pedido_id", pedido.id)
    .order("criado_em", { ascending: false })
    .limit(1)
    .maybeSingle();

  const centralNome = (pedido.centrais as { nome?: string } | null)?.nome ?? "central";
  const status = evento.status ?? pedido.status;
  const tipo = evento.evento ?? "status";
  const dados = { pedido_id: String(pedido.id), numero: String(pedido.numero), status };
  let enviados = 0;

  try {
    const paraCliente = mensagemParaCliente(pedido.numero, status, tipo, ultimo?.observacao ?? "", centralNome);
    if (paraCliente) {
      enviados += await enviar(admin, conta, await tokensDe(admin, [pedido.cliente_id]), paraCliente, dados, "pedidos");
    }

    // Pedido novo ou transferido: avisa os operadores da central responsável.
    if (status === "novo" && (tipo === "status" || tipo === "transferencia")) {
      const { data: operadores } = await admin
        .from("operadores_central")
        .select("perfil_id")
        .eq("central_id", pedido.central_id);
      const ids = (operadores ?? []).map((o) => o.perfil_id as string);
      const hora = String(pedido.hora_inicio).slice(0, 5);
      const quando = `${String(pedido.data_entrega).split("-").reverse().join("/")} às ${hora}`;
      enviados += await enviar(
        admin,
        conta,
        await tokensDe(admin, ids),
        {
          titulo: tipo === "transferencia" ? `Pedido nº ${pedido.numero} transferido para você` : `Novo pedido nº ${pedido.numero}`,
          corpo: `Entrega em ${quando}.`,
        },
        dados,
        "novos_pedidos",
      );
    }
  } catch (erro) {
    console.error("notificar:", erro);
    return resposta(500, { erro: "Falha ao enviar." });
  }

  return resposta(200, { enviado: enviados > 0, quantidade: enviados });
});
