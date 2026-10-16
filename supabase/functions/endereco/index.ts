// Ajuda com endereços: busca o CEP e encontra a localização no mapa.
// Só para usuários logados. Todos os serviços são gratuitos e sem chave.
//
// Ações:
//   { "acao": "cep", "cep": "75600000" }
//   { "acao": "localizar", "logradouro", "numero", "bairro", "cidade", "uf", "cep" }
//   { "acao": "reverso", "latitude", "longitude" }
//
// Cada ação tenta mais de um serviço, na ordem:
//   CEP:       ViaCEP → BrasilAPI
//   Mapa:      Nominatim (OpenStreetMap) → Photon (OpenStreetMap, da Komoot)
//   Cidade:    BrasilAPI (pelo CEP) → Photon → Nominatim
// O Nominatim às vezes recusa o servidor (HTTP 403/429); quando isso acontece,
// ele fica de lado por 10 minutos e o Photon responde no lugar.
import { createClient } from "npm:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const AGENTE = "PlataformaGasAgua/1.0 (contato: fortalezadigitalsecurity@gmail.com)";
const TEMPO_LIMITE_MS = 6000;
const PAUSA_NOMINATIM_MS = 10 * 60 * 1000;

let nominatimPausadoAte = 0;

class ErroHttp extends Error {
  constructor(readonly status: number) {
    super(`HTTP ${status}`);
  }
}

function resposta(status: number, corpo: Record<string, unknown>): Response {
  return new Response(JSON.stringify(corpo), {
    status,
    headers: { ...CORS, "Content-Type": "application/json; charset=utf-8" },
  });
}

function texto(valor: unknown, limite = 120): string {
  return typeof valor === "string" ? valor.trim().slice(0, limite) : "";
}

/** Sem acento, minúsculo e sem espaços sobrando (para comparar nomes). */
function normalizar(valor: string): string {
  return valor.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().replace(/\s+/g, " ").trim();
}

const UF_POR_ESTADO: Record<string, string> = {
  "acre": "AC", "alagoas": "AL", "amapa": "AP", "amazonas": "AM", "bahia": "BA",
  "ceara": "CE", "distrito federal": "DF", "espirito santo": "ES", "goias": "GO",
  "maranhao": "MA", "mato grosso": "MT", "mato grosso do sul": "MS", "minas gerais": "MG",
  "para": "PA", "paraiba": "PB", "parana": "PR", "pernambuco": "PE", "piaui": "PI",
  "rio de janeiro": "RJ", "rio grande do norte": "RN", "rio grande do sul": "RS",
  "rondonia": "RO", "roraima": "RR", "santa catarina": "SC", "sao paulo": "SP",
  "sergipe": "SE", "tocantins": "TO",
};

const ESTADO_POR_UF: Record<string, string> = Object.fromEntries(
  Object.entries(UF_POR_ESTADO).map(([estado, uf]) => [uf, estado]),
);

function ufDoEstado(estado: string | undefined): string {
  if (!estado) return "";
  const limpo = normalizar(estado);
  if (/^[a-z]{2}$/.test(limpo) && ESTADO_POR_UF[limpo.toUpperCase()]) return limpo.toUpperCase();
  return UF_POR_ESTADO[limpo] ?? "";
}

async function buscarJson(url: string): Promise<unknown> {
  const controle = new AbortController();
  const tempo = setTimeout(() => controle.abort(), TEMPO_LIMITE_MS);
  try {
    const r = await fetch(url, {
      headers: { "User-Agent": AGENTE, "Accept-Language": "pt-BR" },
      signal: controle.signal,
    });
    if (!r.ok) throw new ErroHttp(r.status);
    return await r.json();
  } finally {
    clearTimeout(tempo);
  }
}

/** Tenta cada serviço em ordem; devolve o primeiro resultado que servir. */
async function primeiroQueResponder<T>(
  tentativas: Array<[string, () => Promise<T | null>]>,
): Promise<T | null> {
  let falhas = 0;
  for (const [nome, tentar] of tentativas) {
    try {
      const resultado = await tentar();
      if (resultado) return resultado;
    } catch (erro) {
      falhas++;
      console.warn(`endereco: ${nome} falhou:`, String(erro));
    }
  }
  if (falhas === tentativas.length) throw new Error("nenhum serviço respondeu");
  return null;
}

// --------------------------------------------------------------------------
// Nominatim
// --------------------------------------------------------------------------

type LugarNominatim = { lat: string; lon: string; address?: Record<string, string> };

async function nominatim(caminho: string, params: Record<string, string>): Promise<unknown> {
  if (Date.now() < nominatimPausadoAte) throw new Error("em pausa (recusou o servidor há pouco)");
  try {
    return await buscarJson(`https://nominatim.openstreetmap.org/${caminho}?${new URLSearchParams(params)}`);
  } catch (erro) {
    if (erro instanceof ErroHttp && (erro.status === 403 || erro.status === 429)) {
      nominatimPausadoAte = Date.now() + PAUSA_NOMINATIM_MS;
    }
    throw erro;
  }
}

async function nominatimBusca(params: Record<string, string>): Promise<LugarNominatim | null> {
  const lista = await nominatim("search", {
    format: "jsonv2", countrycodes: "br", limit: "1", addressdetails: "1", ...params,
  });
  return Array.isArray(lista) && lista.length > 0 ? (lista[0] as LugarNominatim) : null;
}

// --------------------------------------------------------------------------
// Photon
// --------------------------------------------------------------------------

type Feicao = {
  geometry?: { coordinates?: [number, number] };
  properties?: Record<string, string>;
};

async function photon(caminho: string, params: Array<[string, string]>): Promise<Feicao[]> {
  const qs = new URLSearchParams(params);
  const r = await buscarJson(`https://photon.komoot.io/${caminho}?${qs}`) as { features?: Feicao[] };
  return (r?.features ?? []).filter((f) =>
    (f.properties?.countrycode ?? "").toUpperCase() === "BR" && Array.isArray(f.geometry?.coordinates)
  );
}

const PREFIXOS_DE_RUA = new Set([
  "rua", "r", "avenida", "av", "travessa", "tv", "alameda", "al", "praca", "pc", "rodovia", "rod",
  "estrada", "est", "viela", "via", "largo", "lg", "de", "da", "do", "das", "dos", "e",
]);

function palavrasDaRua(nome: string): string[] {
  return normalizar(nome).replace(/[^a-z0-9 ]/g, " ").split(" ")
    .filter((p) => p.length > 0 && !PREFIXOS_DE_RUA.has(p));
}

/** A rua achada é a pedida? ("Rua Amazonas" aceita "Rua Rio Amazonas".) */
function mesmaRua(pedida: string, achada: string): boolean {
  const a = palavrasDaRua(pedida);
  const b = palavrasDaRua(achada);
  if (a.length === 0 || b.length === 0) return false;
  return a.every((p) => b.includes(p)) || b.every((p) => a.includes(p));
}

function cidadeDaFeicao(p: Record<string, string>): string {
  return p.city ?? (p.type === "city" ? p.name : undefined) ?? p.county ?? "";
}

function mesmaCidade(p: Record<string, string>, cidade: string, uf: string): boolean {
  const alvo = normalizar(cidade);
  const nomes = [p.city, p.county, p.type === "city" ? p.name : undefined]
    .filter((n): n is string => !!n)
    .map(normalizar);
  const estadoConfere = !uf || !p.state || ufDoEstado(p.state) === uf;
  return estadoConfere && nomes.includes(alvo);
}

// --------------------------------------------------------------------------
// BrasilAPI (CEP com coordenadas, quando houver)
// --------------------------------------------------------------------------

type CepBrasilApi = {
  cep?: string; state?: string; city?: string; neighborhood?: string | null; street?: string | null;
  location?: { coordinates?: { latitude?: string; longitude?: string } };
};

async function brasilApiCep(cep: string): Promise<CepBrasilApi | null> {
  try {
    return await buscarJson(`https://brasilapi.com.br/api/cep/v2/${cep}`) as CepBrasilApi;
  } catch (erro) {
    if (erro instanceof ErroHttp && erro.status === 404) return null;
    throw erro;
  }
}

function coordenadasValidas(lat: number, lon: number): boolean {
  return Number.isFinite(lat) && Number.isFinite(lon) && Math.abs(lat) <= 90 && Math.abs(lon) <= 180 &&
    !(lat === 0 && lon === 0);
}

// --------------------------------------------------------------------------
// Ações
// --------------------------------------------------------------------------

type Ponto = { latitude: number; longitude: number; precisao: "endereco" | "rua" | "cidade" };

async function acaoCep(cep: string): Promise<Record<string, string> | null> {
  return await primeiroQueResponder<Record<string, string>>([
    ["viacep", async () => {
      const r = await buscarJson(`https://viacep.com.br/ws/${cep}/json/`) as Record<string, string>;
      if (!r || r.erro) return null;
      return {
        cep,
        logradouro: r.logradouro ?? "",
        bairro: r.bairro ?? "",
        cidade: r.localidade ?? "",
        uf: (r.uf ?? "").toUpperCase(),
      };
    }],
    ["brasilapi", async () => {
      const r = await brasilApiCep(cep);
      if (!r?.city) return null;
      return {
        cep,
        logradouro: r.street ?? "",
        bairro: r.neighborhood ?? "",
        cidade: r.city,
        uf: (r.state ?? "").toUpperCase(),
      };
    }],
  ]);
}

async function acaoLocalizar(d: {
  logradouro: string; numero: string; bairro: string; cidade: string; uf: string; cep: string;
}): Promise<Ponto | null> {
  const estado = ESTADO_POR_UF[d.uf] ?? d.uf;
  const ponto = (lat: string | number, lon: string | number, precisao: Ponto["precisao"]): Ponto | null => {
    const latitude = Number(lat);
    const longitude = Number(lon);
    return coordenadasValidas(latitude, longitude) ? { latitude, longitude, precisao } : null;
  };

  const tentativas: Array<[string, () => Promise<Ponto | null>]> = [];
  if (d.logradouro) {
    tentativas.push(
      ["nominatim-endereco", async () => {
        const l = await nominatimBusca({ street: `${d.numero} ${d.logradouro}`.trim(), city: d.cidade, state: d.uf });
        return l ? ponto(l.lat, l.lon, "endereco") : null;
      }],
      ["photon-endereco", async () => {
        const consulta = [`${d.logradouro} ${d.numero}`.trim(), d.bairro, d.cidade, estado].filter(Boolean).join(", ");
        const lista = await photon("api", [["q", consulta], ["limit", "5"], ["layer", "house"], ["layer", "street"]]);
        const achado = lista.find((f) => {
          const p = f.properties ?? {};
          return mesmaCidade(p, d.cidade, d.uf) && mesmaRua(d.logradouro, p.street ?? p.name ?? "");
        });
        if (!achado) return null;
        const [lon, lat] = achado.geometry!.coordinates!;
        const p = achado.properties ?? {};
        const exato = p.type === "house" && !!p.housenumber && normalizar(p.housenumber) === normalizar(d.numero);
        return ponto(lat, lon, exato ? "endereco" : "rua");
      }],
      ["nominatim-rua", async () => {
        const l = await nominatimBusca({ q: `${d.logradouro}, ${d.bairro}, ${d.cidade}, ${d.uf}` });
        return l ? ponto(l.lat, l.lon, "rua") : null;
      }],
    );
  }
  if (d.cep.length === 8) {
    tentativas.push(["brasilapi-cidade", async () => {
      const r = await brasilApiCep(d.cep);
      const c = r?.location?.coordinates;
      if (!r?.city || !c || normalizar(r.city) !== normalizar(d.cidade)) return null;
      return ponto(c.latitude ?? "", c.longitude ?? "", "cidade");
    }]);
  }
  tentativas.push(
    ["photon-cidade", async () => {
      const lista = await photon("api", [["q", `${d.cidade}, ${estado}`], ["limit", "5"], ["layer", "city"]]);
      const achado = lista.find((f) => mesmaCidade(f.properties ?? {}, d.cidade, d.uf));
      if (!achado) return null;
      const [lon, lat] = achado.geometry!.coordinates!;
      return ponto(lat, lon, "cidade");
    }],
    ["nominatim-cidade", async () => {
      const l = await nominatimBusca({ city: d.cidade, state: d.uf });
      return l ? ponto(l.lat, l.lon, "cidade") : null;
    }],
  );
  return await primeiroQueResponder(tentativas);
}

type EnderecoReverso = {
  cep: string; logradouro: string; numero: string; bairro: string; cidade: string; uf: string;
};

async function acaoReverso(latitude: number, longitude: number): Promise<EnderecoReverso | null> {
  return await primeiroQueResponder<EnderecoReverso>([
    ["nominatim", async () => {
      const r = await nominatim("reverse", {
        format: "jsonv2", lat: String(latitude), lon: String(longitude), addressdetails: "1", zoom: "18",
      }) as LugarNominatim | null;
      const a = r?.address;
      if (!a) return null;
      const estado = (a["ISO3166-2-lvl4"] ?? "").replace(/^BR-/, "");
      return {
        cep: (a.postcode ?? "").replace(/\D/g, ""),
        logradouro: a.road ?? a.pedestrian ?? a.street ?? "",
        numero: a.house_number ?? "",
        bairro: a.suburb ?? a.neighbourhood ?? a.quarter ?? a.village ?? "",
        cidade: a.city ?? a.town ?? a.municipality ?? a.village ?? "",
        uf: estado.length === 2 ? estado : ufDoEstado(a.state),
      };
    }],
    ["photon", async () => {
      const lista = await photon("reverse", [
        ["lat", String(latitude)], ["lon", String(longitude)], ["limit", "1"], ["layer", "house"], ["layer", "street"],
      ]);
      const p = lista[0]?.properties;
      if (!p) return null;
      return {
        cep: (p.postcode ?? "").replace(/\D/g, ""),
        logradouro: p.street ?? (p.type === "street" ? p.name : "") ?? "",
        numero: p.housenumber ?? "",
        bairro: p.district ?? p.locality ?? "",
        cidade: cidadeDaFeicao(p),
        uf: ufDoEstado(p.state),
      };
    }],
  ]);
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
      const r = await acaoCep(cep);
      if (!r) return resposta(404, { erro: "CEP não encontrado. Confira os números." });
      return resposta(200, r);
    }

    if (acao === "localizar") {
      const d = {
        logradouro: texto(dados.logradouro),
        numero: texto(dados.numero, 20),
        bairro: texto(dados.bairro, 80),
        cidade: texto(dados.cidade, 80),
        uf: texto(dados.uf, 2).toUpperCase(),
        cep: texto(dados.cep, 20).replace(/\D/g, ""),
      };
      if (!d.cidade || !d.uf) return resposta(400, { erro: "Informe a cidade e o estado." });
      const p = await acaoLocalizar(d);
      if (!p) return resposta(404, { erro: "Não encontramos esse endereço no mapa." });
      return resposta(200, p);
    }

    if (acao === "reverso") {
      const latitude = Number(dados.latitude);
      const longitude = Number(dados.longitude);
      if (!coordenadasValidas(latitude, longitude)) {
        return resposta(400, { erro: "Localização inválida." });
      }
      const r = await acaoReverso(latitude, longitude);
      return resposta(200, {
        latitude,
        longitude,
        ...(r ?? { cep: "", logradouro: "", numero: "", bairro: "", cidade: "", uf: "" }),
      });
    }

    return resposta(400, { erro: "Ação desconhecida." });
  } catch (erro) {
    console.error("endereco:", acao, String(erro));
    return resposta(502, { erro: "O serviço de endereços não respondeu. Tente de novo." });
  }
});
