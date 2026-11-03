/** SMS price query parsing and replies (pure; unit tested). */
export interface SmsCommodity {
  id: string;
  nameFil: string;
  nameEn: string;
  unit: string;
}
export interface SmsMarket {
  id: string;
  name: string;
  municipality: string;
}
export interface SmsBoard {
  commodityId: string;
  marketId: string;
  medianPrice: number;
  confidence: 'high' | 'medium' | 'low';
  latestReportAt: number;
  isDemo: boolean;
}

/** Uppercase, strip accents and punctuation, collapse spaces. */
export function norm(s: string): string {
  return s
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toUpperCase()
    .replace(/[^A-Z0-9 ]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

const COMMANDS = ['PRESYO', 'PRICE', 'P'];
const HELP = ['TULONG', 'HELP', 'INFO', '?'];

export type Parsed =
  | { kind: 'help' }
  | { kind: 'unknown'; word: string }
  | { kind: 'query'; commodity: SmsCommodity; marketQuery: string };

export function parseSms(text: string, commodities: SmsCommodity[]): Parsed {
  const raw = text.trim().toUpperCase();
  if (raw === '' || HELP.includes(raw)) return { kind: 'help' };
  let tokens = norm(text).split(' ').filter(Boolean);
  if (tokens.length && COMMANDS.includes(tokens[0])) tokens = tokens.slice(1);
  if (!tokens.length) return { kind: 'help' };

  // Longest prefix of tokens that names a commodity (Filipino, English or id).
  const names = commodities.map((c) => ({
    c,
    keys: [norm(c.nameFil), norm(c.nameEn), norm(c.id.replace(/-/g, ' '))].filter(Boolean),
  }));
  for (let n = Math.min(tokens.length, 4); n >= 1; n--) {
    const candidate = tokens.slice(0, n).join(' ');
    const hit = names.find((x) => x.keys.includes(candidate));
    if (hit) return { kind: 'query', commodity: hit.c, marketQuery: tokens.slice(n).join(' ') };
  }
  return { kind: 'unknown', word: tokens[0].slice(0, 20) };
}

export function matchMarkets(query: string, markets: SmsMarket[]): SmsMarket[] {
  if (!query) return markets;
  const q = norm(query);
  return markets.filter(
    (m) =>
      norm(m.municipality) === q || norm(m.name).includes(q) || norm(m.municipality).includes(q),
  );
}

const CONF = { high: 'Mataas', medium: 'Katamtaman', low: 'Mababa' } as const;
const UNIT: Record<string, string> = { kg: 'kilo', bundle: 'tali', piece: 'piraso' };

export function ageText(now: number, t: number): string {
  const h = Math.floor((now - t) / 3600_000);
  if (h < 1) return 'ngayon lang';
  if (h < 24) return `${h} oras na`;
  return `${Math.floor(h / 24)} araw na`;
}

export const HELP_TEXT =
  'TIMBANG: I-text ang PRESYO <gulay> <bayan>. Hal: PRESYO KAMATIS BAYOMBONG. Median ng ulat; hindi itinatakda ng TIMBANG ang presyo.';

/** Builds the reply. GSM-7 only (P not ₱), no personal data. */
export function buildReply(
  parsed: Parsed,
  data: { markets: SmsMarket[]; boards: SmsBoard[]; now: number },
): string {
  if (parsed.kind === 'help') return HELP_TEXT;
  if (parsed.kind === 'unknown') {
    return `TIMBANG: Hindi kilala ang "${parsed.word}". I-text: PRESYO <gulay> <bayan>. Hal: PRESYO KAMATIS BAYOMBONG`;
  }
  const c = parsed.commodity;
  const markets = matchMarkets(parsed.marketQuery, data.markets);
  if (parsed.marketQuery && markets.length === 0) {
    return `TIMBANG: Hindi kilala ang palengke/bayan "${parsed.marketQuery.slice(0, 20)}". Hal: PRESYO ${norm(c.nameFil)} BAYOMBONG`;
  }
  const ids = new Set(markets.map((m) => m.id));
  const rank = { high: 0, medium: 1, low: 2 };
  const rows = data.boards
    .filter((b) => b.commodityId === c.id && ids.has(b.marketId))
    .sort((a, b) => b.latestReportAt - a.latestReportAt || rank[a.confidence] - rank[b.confidence])
    .slice(0, parsed.marketQuery ? 1 : 2);
  const where = parsed.marketQuery ? ` sa ${markets[0].municipality}` : '';
  if (!rows.length) return `TIMBANG: Wala pang presyo ng ${c.nameFil}${where}. I-text ulit mamaya.`;
  const byId = new Map(data.markets.map((m) => [m.id, m]));
  const parts = rows.map((b) => {
    const stale = data.now - b.latestReportAt > 24 * 3600_000 ? ' LUMA NA' : '';
    return `${byId.get(b.marketId)!.name} P${b.medianPrice.toFixed(2)}/${UNIT[c.unit] ?? c.unit}, ${CONF[b.confidence]}, ${ageText(data.now, b.latestReportAt)}${stale}`;
  });
  const demo = rows.some((b) => b.isDemo) ? '[DEMO, hindi totoo] ' : '';
  return `TIMBANG: ${demo}${c.nameFil}: ${parts.join('; ')}. Median ng ulat.`;
}
