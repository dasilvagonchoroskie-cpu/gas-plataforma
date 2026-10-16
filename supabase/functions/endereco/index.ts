// Ajuda com endereços: busca o CEP (ViaCEP) e encontra a localização no mapa
// (Nominatim / OpenStreetMap). Só para usuários logados.
//
// Ações:
//   { "acao": "cep", "cep": "75600000" }
//   { "acao": "localizar", "logradouro", "numero", "bairro", "cidade", "uf", "cep" }
//   { "acao": "reverso", "latitude", "longitude" }
import { createClient } from "npm:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const AGENTE = "PlataformaGasAgua/1.0 (contato: fortalezadigitalsecurity@gmail.com)";
const TEMPO_LIMITE_MS = 8000;

function resposta(status: number, corpo: Record<string, unknown>): Response {
  return new Response(JSON.stringify(corpo), {
    status,
    headers: { ...CORS, "Content-Type": "application/json; charset=utf-8" },
  });
}

function texto(valor: unknown, limite = 120): string {
  return typeof valor === "string" ? valor.trim().slice(0, limite) : "";
}

async function buscarJson(url: string): Promise<unknown> {
  const controle = new AbortController();
  const tempo = setTimeout(() => controle.abort(), TEMPO_LIMITE_MS);
  try {
    const r = await fetch(url, {
      headers: { "User-Agent": AGENTE, "Accept-Language": "pt-BR" },
      signal: controle.signal,
    });
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    return await r.json();
  } finally {
    clearTimeout(tempo);
  }
}

type Lugar = { lat: string; lon: string; address?: Record<string, string> };

async function nominatimBusca(params: Record<string, string>): Promise<Lugar | null> {
  const qs = new URLSearchParams({ format: "jsonv2", countrycodes: "br", limit: "1", addressdetails: "1", ...params });
  const lista = await buscarJson(`https://nominatim.openstreetmap.org/search?${qs}`);
  return Array.isArray(lista) && lista.length > 0 ? (lista[0] as Lugar) : null;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  if (req.method !== "POST") return resposta(405, { erro: "Método não permitido." });

  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: usuario } = token ? await admin.auth.getUser(token) : { data: null };
  if (!usuario?.user) return resposta(401, { erro: "Faça login novamente." });

  const dados = await req.json().catch(() => ({})) as Record<string, unknown>;
  const acao = texto(dados.acao, 20);

  try {
    if (acao === "cep") {
      const cep = texto(dados.cep, 20).replace(/\D/g, "");
      if (cep.length !== 8) return resposta(400, { erro: "CEP precisa ter 8 números." });
      const r = await buscarJson(`https://viacep.com.br/ws/${cep}/json/`) as Record<string, string>;
      if (!r || r.erro) return resposta(404, { erro: "CEP não encontrado. Confira os números." });
      return resposta(200, {
        cep,
        logradouro: r.logradouro ?? "",
        bairro: r.bairro ?? "",
        cidade: r.localidade ?? "",
        uf: (r.uf ?? "").toUpperCase(),
      });
    }

    if (acao === "localizar") {
      const logradouro = texto(dados.logradouro);
      const numero = texto(dados.numero, 20);
      const bairro = texto(dados.bairro, 80);
      const cidade = texto(dados.cidade, 80);
      const uf = texto(dados.uf, 2).toUpperCase();
      if (!cidade || !uf) return resposta(400, { erro: "Informe a cidade e o estado." });

      // 1º: rua e número. 2º: rua e bairro. 3º: só a cidade (aproximado).
      let lugar = logradouro
        ? await nominatimBusca({ street: `${numero} ${logradouro}`.trim(), city: cidade, state: uf })
        : null;
      let precisao = "endereco";
      if (!lugar && logradouro) {
        lugar = await nominatimBusca({ q: `${logradouro}, ${bairro}, ${cidade}, ${uf}` });
        precisao = "rua";
      }
      if (!lugar) {
        lugar = await nominatimBusca({ city: cidade, state: uf });
        precisao = "cidade";
      }
      if (!lugar) return resposta(404, { erro: "Não encontramos esse endereço no mapa." });
      return resposta(200, {
        latitude: Number(lugar.lat),
        longitude: Number(lugar.lon),
        precisao,
      });
    }

    if (acao === "reverso") {
      const latitude = Number(dados.latitude);
      const longitude = Number(dados.longitude);
      if (!Number.isFinite(latitude) || !Number.isFinite(longitude) ||
          Math.abs(latitude) > 90 || Math.abs(longitude) > 180) {
        return resposta(400, { erro: "Localização inválida." });
      }
      const qs = new URLSearchParams({
        format: "jsonv2", lat: String(latitude), lon: String(longitude), addressdetails: "1", zoom: "18",
      });
      const r = await buscarJson(`https://nominatim.openstreetmap.org/reverse?${qs}`) as Lugar;
      const a = r?.address ?? {};
      const estado = (a["ISO3166-2-lvl4"] ?? "").replace(/^BR-/, "");
      return resposta(200, {
        latitude,
        longitude,
        cep: (a.postcode ?? "").replace(/\D/g, ""),
        logradouro: a.road ?? a.pedestrian ?? a.street ?? "",
        numero: a.house_number ?? "",
        bairro: a.suburb ?? a.neighbourhood ?? a.quarter ?? a.village ?? "",
        cidade: a.city ?? a.town ?? a.municipality ?? a.village ?? "",
        uf: estado.length === 2 ? estado : "",
      });
    }

    return resposta(400, { erro: "Ação desconhecida." });
  } catch (erro) {
    console.error("endereco:", acao, erro);
    return resposta(502, { erro: "O serviço de endereços não respondeu. Tente de novo." });
  }
});
