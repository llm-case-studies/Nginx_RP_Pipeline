import { test, expect } from '@playwright/test';

const hosts = [
  'iLegalFlow.com',
  'VW.iLegalFlow.com',
  'Crypto-Fakes.com',
  'cutietraders.com',
  'CutieTraders.com',
  'iMediFlow.com',
];

const httpsPort = process.env.BASE_HTTPS || '8446';
const httpPort = process.env.BASE_HTTP || '8083';

for (const host of hosts) {
  test.describe(`TLS and redirect for ${host}`, () => {
    test(`HTTPS loads with valid cert: ${host}`, async ({ page, request }) => {
      const res = await request.get(`https://${host}:${httpsPort}/`, { ignoreHTTPSErrors: false });
      expect(res.status()).toBe(200);
    });

    test(`HTTP redirects to HTTPS: ${host}`, async ({ request }) => {
      const res = await request.get(`http://${host}:${httpPort}/`, { maxRedirects: 0 });
      expect([301, 302, 308]).toContain(res.status());
      const loc = res.headers()['location'] || res.headers()['Location'];
      expect(loc).toBeTruthy();
      expect(loc).toContain(`https://${host}`);
    });
  });
}


