/**
 * Yahoo Finance CORS Proxy — manual crumb/cookie session
 *
 * Yahoo now requires a valid browser session (cookie + crumb) for all API calls.
 * This proxy:
 *   1. On startup (and on demand), fetches a cookie from fc.yahoo.com
 *   2. Extracts the crumb from the Yahoo Finance API crumb endpoint
 *   3. Appends the crumb to all downstream requests and forwards the cookie
 *   4. Re-authenticates automatically when the session expires
 *
 * Routes exposed (same URL shape as the old Yahoo v10/v8 API):
 *   GET /v10/finance/quoteSummary/:symbol?modules=...
 *   GET /v8/finance/chart/:symbol?range=1mo&interval=1d
 *
 * Run with: node server.js
 * Listens on http://localhost:8080
 */

const http = require('http');
const https = require('https');
const { URL } = require('url');

const PORT = 8080;

// ─────────────────────────────────────────────────────────────────────────────
// Session state
// ─────────────────────────────────────────────────────────────────────────────

let _cookie = '';
let _crumb = '';

const BASE_HEADERS = {
  'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  Accept: 'application/json, text/plain, */*',
  'Accept-Language': 'en-US,en;q=0.9',
  'Accept-Encoding': 'gzip, deflate, br',
  Connection: 'keep-alive',
};

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

function httpsGet(urlString, headers = {}) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(urlString);
    const options = {
      hostname: parsed.hostname,
      path: parsed.pathname + parsed.search,
      method: 'GET',
      headers: { ...BASE_HEADERS, ...headers },
    };

    const req = https.request(options, (res) => {
      const chunks = [];
      // Handle gzip/deflate transparently
      let stream = res;
      const enc = res.headers['content-encoding'];
      if (enc === 'gzip' || enc === 'deflate' || enc === 'br') {
        const zlib = require('zlib');
        const decompress =
          enc === 'gzip'
            ? zlib.createGunzip()
            : enc === 'br'
            ? zlib.createBrotliDecompress()
            : zlib.createInflate();
        res.pipe(decompress);
        stream = decompress;
      }
      stream.on('data', (c) => chunks.push(c));
      stream.on('end', () =>
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          body: Buffer.concat(chunks).toString('utf-8'),
        })
      );
      stream.on('error', reject);
    });

    req.on('error', reject);
    req.setTimeout(15000, () => {
      req.destroy(new Error('Request timed out'));
    });
    req.end();
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Auth — fetch Yahoo cookie + crumb
// ─────────────────────────────────────────────────────────────────────────────

async function authenticate() {
  console.log('[auth] Fetching Yahoo Finance session...');

  // Step 1: Hit fc.yahoo.com to get the consent cookie
  const fcRes = await httpsGet('https://fc.yahoo.com');
  const setCookieHeaders = fcRes.headers['set-cookie'] || [];
  const cookieParts = setCookieHeaders.map((c) => c.split(';')[0]);
  _cookie = cookieParts.join('; ');

  if (!_cookie) {
    // Try alternate consent endpoint
    const consentRes = await httpsGet(
      'https://consent.yahoo.com/v2/collectConsent?sessionId=1',
      {}
    );
    const consentCookies = (consentRes.headers['set-cookie'] || []).map(
      (c) => c.split(';')[0]
    );
    _cookie = consentCookies.join('; ');
  }

  console.log(`[auth] Got cookie: ${_cookie ? _cookie.substring(0, 60) + '...' : '(empty)'}`);

  // Step 2: Fetch crumb using the cookie
  const crumbRes = await httpsGet(
    'https://query1.finance.yahoo.com/v1/test/getcrumb',
    { Cookie: _cookie }
  );

  if (crumbRes.statusCode === 200 && crumbRes.body && crumbRes.body !== 'null') {
    _crumb = crumbRes.body.trim().replace(/"/g, '');
    console.log(`[auth] Got crumb: ${_crumb}`);
    return true;
  }

  // Alternate crumb endpoint
  const crumbRes2 = await httpsGet(
    'https://query2.finance.yahoo.com/v1/test/getcrumb',
    { Cookie: _cookie }
  );
  if (crumbRes2.statusCode === 200 && crumbRes2.body && crumbRes2.body !== 'null') {
    _crumb = crumbRes2.body.trim().replace(/"/g, '');
    console.log(`[auth] Got crumb (v2): ${_crumb}`);
    return true;
  }

  console.error('[auth] Failed to obtain crumb.');
  return false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Proxy a Yahoo Finance request with session
// ─────────────────────────────────────────────────────────────────────────────

async function yahooFetch(path, query = {}) {
  // Ensure we have a session
  if (!_crumb || !_cookie) {
    await authenticate();
  }

  const params = new URLSearchParams({ ...query, crumb: _crumb });
  const urlString = `https://query1.finance.yahoo.com${path}?${params.toString()}`;

  console.log(`[proxy] → ${urlString}`);

  let res = await httpsGet(urlString, { Cookie: _cookie });

  // Session expired — re-auth once and retry
  if (res.statusCode === 401 || res.body.includes('Invalid Crumb')) {
    console.warn('[proxy] Session expired, re-authenticating...');
    await authenticate();
    const params2 = new URLSearchParams({ ...query, crumb: _crumb });
    const urlString2 = `https://query1.finance.yahoo.com${path}?${params2.toString()}`;
    res = await httpsGet(urlString2, { Cookie: _cookie });
  }

  console.log(`[proxy] ← ${res.statusCode}`);
  return res;
}

// ─────────────────────────────────────────────────────────────────────────────
// HTTP helpers
// ─────────────────────────────────────────────────────────────────────────────

function setCors(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
}

function sendJson(res, statusCode, data) {
  res.writeHead(statusCode, { 'Content-Type': 'application/json' });
  res.end(typeof data === 'string' ? data : JSON.stringify(data));
}

function sendError(res, statusCode, message) {
  console.error(`[proxy] ✗ ${message}`);
  sendJson(res, statusCode, { error: message });
}

// ─────────────────────────────────────────────────────────────────────────────
// HTTP Server — route requests
// ─────────────────────────────────────────────────────────────────────────────

const server = http.createServer(async (req, res) => {
  setCors(res);

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  if (req.method !== 'GET') {
    return sendError(res, 405, 'Method not allowed');
  }

  const parsed = new URL(req.url, `http://localhost:${PORT}`);
  const pathname = parsed.pathname;

  // ── Route: /v10/finance/quoteSummary/:symbol ──────────────────────────────
  const quoteMatch = pathname.match(/^\/v10\/finance\/quoteSummary\/(.+)$/);
  if (quoteMatch) {
    const symbol = decodeURIComponent(quoteMatch[1]);
    const modules =
      parsed.searchParams.get('modules') ||
      'price,summaryDetail,defaultKeyStatistics,financialData,earnings,incomeStatementHistory';

    try {
      const upstream = await yahooFetch(`/v10/finance/quoteSummary/${symbol}`, {
        modules,
      });

      if (upstream.statusCode !== 200) {
        return sendError(
          res,
          upstream.statusCode,
          `Yahoo returned ${upstream.statusCode} for ${symbol}`
        );
      }
      return sendJson(res, 200, upstream.body);
    } catch (err) {
      return sendError(res, 502, `quoteSummary failed: ${err.message}`);
    }
  }

  // ── Route: /v8/finance/chart/:symbol ─────────────────────────────────────
  const chartMatch = pathname.match(/^\/v8\/finance\/chart\/(.+)$/);
  if (chartMatch) {
    const symbol = decodeURIComponent(chartMatch[1]);
    const query = {};
    for (const [k, v] of parsed.searchParams.entries()) query[k] = v;

    try {
      const upstream = await yahooFetch(`/v8/finance/chart/${symbol}`, query);

      if (upstream.statusCode !== 200) {
        return sendError(
          res,
          upstream.statusCode,
          `Yahoo chart returned ${upstream.statusCode} for ${symbol}`
        );
      }
      return sendJson(res, 200, upstream.body);
    } catch (err) {
      return sendError(res, 502, `chart failed: ${err.message}`);
    }
  }

  return sendError(res, 404, `Unknown route: ${pathname}`);
});

// ─────────────────────────────────────────────────────────────────────────────
// Boot
// ─────────────────────────────────────────────────────────────────────────────

(async () => {
  try {
    await authenticate();
  } catch (err) {
    console.warn(`[auth] Initial auth failed (${err.message}) — will retry on first request`);
  }

  server.listen(PORT, () => {
    console.log(`✅  Yahoo Finance proxy listening on http://localhost:${PORT}`);
    console.log(`   Start Flutter web with: flutter run -d chrome`);
  });
})();
