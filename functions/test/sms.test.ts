import { MockSmsGateway, hmacHex, maskNumber, verifyHmac } from '../src/sms/gateway';
import { HELP_TEXT, buildReply, matchMarkets, norm, parseSms } from '../src/sms/query';
import { SmsStore, handleSms, numberKey } from '../src/sms/service';

const NOW = Date.UTC(2026, 10, 3, 4);
const H = 3600_000;
const commodities = [
  { id: 'kamatis', nameFil: 'Kamatis', nameEn: 'Tomato', unit: 'kg' },
  { id: 'sitaw', nameFil: 'Sitaw', nameEn: 'String beans', unit: 'bundle' },
  { id: 'pechay', nameFil: 'Pechay', nameEn: 'Pechay (bok choy)', unit: 'bundle' },
];
const markets = [
  { id: 'bpm', name: 'Bayombong Public Market', municipality: 'Bayombong' },
  { id: 'spm', name: 'Solano Public Market', municipality: 'Solano' },
  { id: 'nvat', name: 'NVAT Trading Post (Bambang)', municipality: 'Bambang' },
];
const boards = [
  {
    commodityId: 'kamatis',
    marketId: 'bpm',
    medianPrice: 64,
    confidence: 'high' as const,
    latestReportAt: NOW - 2 * H,
    isDemo: false,
  },
  {
    commodityId: 'kamatis',
    marketId: 'spm',
    medianPrice: 61,
    confidence: 'low' as const,
    latestReportAt: NOW - 30 * H,
    isDemo: false,
  },
  {
    commodityId: 'sitaw',
    marketId: 'bpm',
    medianPrice: 30,
    confidence: 'medium' as const,
    latestReportAt: NOW - 20 * 60_000,
    isDemo: true,
  },
];

describe('parse', () => {
  test('norm strips accents and punctuation', () => {
    expect(norm(' presyo, kamatís!  bayombong ')).toBe('PRESYO KAMATIS BAYOMBONG');
  });
  test.each([
    ['PRESYO KAMATIS BAYOMBONG', 'kamatis', 'BAYOMBONG'],
    ['presyo kamatis', 'kamatis', ''],
    ['PRICE TOMATO SOLANO', 'kamatis', 'SOLANO'],
    ['KAMATIS BAYOMBONG', 'kamatis', 'BAYOMBONG'],
    ['P STRING BEANS NVAT', 'sitaw', 'NVAT'],
  ])('%s', (text, commodity, market) => {
    const p = parseSms(text, commodities);
    expect(p).toMatchObject({ kind: 'query', commodity: { id: commodity }, marketQuery: market });
  });
  test('help and unknown', () => {
    expect(parseSms('TULONG', commodities)).toEqual({ kind: 'help' });
    expect(parseSms('PRESYO', commodities)).toEqual({ kind: 'help' });
    expect(parseSms('PRESYO GINTO', commodities)).toEqual({ kind: 'unknown', word: 'GINTO' });
  });
  test('market matching by town or name', () => {
    expect(matchMarkets('BAMBANG', markets).map((m) => m.id)).toEqual(['nvat']);
    expect(matchMarkets('NVAT', markets).map((m) => m.id)).toEqual(['nvat']);
  });
});

describe('reply', () => {
  const data = { markets, boards, now: NOW };
  test('with market: price, unit, confidence, age; GSM-safe', () => {
    const r = buildReply(parseSms('PRESYO KAMATIS BAYOMBONG', commodities), data);
    expect(r).toBe(
      'TIMBANG: Kamatis: Bayombong Public Market P64.00/kilo, Mataas, 2 oras na. Median ng ulat.',
    );
    expect(r).not.toContain('₱');
    expect(r.length).toBeLessThanOrEqual(160);
  });
  test('without market: freshest two; stale flagged', () => {
    const r = buildReply(parseSms('PRESYO KAMATIS', commodities), data);
    expect(r).toContain('Bayombong Public Market P64.00');
    expect(r).toContain('Solano Public Market P61.00/kilo, Mababa, 1 araw na LUMA NA');
  });
  test('demo data is labeled', () => {
    expect(buildReply(parseSms('PRESYO SITAW', commodities), data)).toContain(
      '[DEMO, hindi totoo]',
    );
  });
  test('no price / unknown market / help', () => {
    expect(buildReply(parseSms('PRESYO PECHAY', commodities), data)).toContain(
      'Wala pang presyo ng Pechay',
    );
    expect(buildReply(parseSms('PRESYO KAMATIS MAKATI', commodities), data)).toContain(
      'Hindi kilala ang palengke/bayan',
    );
    expect(buildReply(parseSms('???', commodities), data)).toBe(HELP_TEXT);
    expect(buildReply({ kind: 'help' }, data)).toBe(HELP_TEXT);
  });
});

describe('gateway security', () => {
  const secret = 'test-secret';
  const body = JSON.stringify({ from: '+639171234567', text: 'PRESYO KAMATIS' });
  test('valid HMAC accepted, anything else rejected', () => {
    const g = new MockSmsGateway(secret);
    expect(
      g.verifyWebhook({ headers: { 'x-timbang-signature': hmacHex(secret, body) }, rawBody: body }),
    ).toEqual({
      from: '+639171234567',
      text: 'PRESYO KAMATIS',
    });
    expect(
      g.verifyWebhook({
        headers: { 'x-timbang-signature': hmacHex('wrong', body) },
        rawBody: body,
      }),
    ).toBeNull();
    expect(g.verifyWebhook({ headers: {}, rawBody: body })).toBeNull();
    const bad = JSON.stringify({ from: 'hacker', text: 'x' });
    expect(
      g.verifyWebhook({ headers: { 'x-timbang-signature': hmacHex(secret, bad) }, rawBody: bad }),
    ).toBeNull();
  });
  test('empty secret fails closed', () => {
    expect(verifyHmac('', body, hmacHex('', body))).toBe(false);
  });
  test('numbers are masked in logs and hashed for rate limits', () => {
    expect(maskNumber('+639171234567')).toBe('+63917***4567');
    expect(numberKey('+639171234567')).not.toContain('917');
  });
});

describe('handleSms', () => {
  function store(): SmsStore & { hits: Map<string, number> } {
    const hits = new Map<string, number>();
    return {
      hits,
      now: () => NOW,
      commodities: async () => commodities,
      markets: async () => markets,
      boardsFor: async (id) => boards.filter((b) => b.commodityId === id),
      hit: async (key) => {
        hits.set(key, (hits.get(key) ?? 0) + 1);
        return hits.get(key)!;
      },
    };
  }
  test('replies through the gateway; never includes the sender number', async () => {
    const g = new MockSmsGateway('s');
    const log = jest.spyOn(console, 'log').mockImplementation(() => {});
    const r = await handleSms(
      { from: '+639171234567', text: 'PRESYO KAMATIS BAYOMBONG' },
      store(),
      g,
    );
    expect(r).toContain('P64.00');
    expect(g.outbox).toEqual([{ to: '+639171234567', text: r }]);
    expect(r).not.toContain('9171234567');
    log.mockRestore();
  });
  test('rate limited after 10 per hour: no reply', async () => {
    const s = store();
    const g = new MockSmsGateway('s');
    const log = jest.spyOn(console, 'log').mockImplementation(() => {});
    const warn = jest.spyOn(console, 'warn').mockImplementation(() => {});
    for (let i = 0; i < 10; i++) await handleSms({ from: '+639170000000', text: 'TULONG' }, s, g);
    expect(await handleSms({ from: '+639170000000', text: 'TULONG' }, s, g)).toBeNull();
    expect(g.outbox).toHaveLength(10);
    log.mockRestore();
    warn.mockRestore();
  });
});
