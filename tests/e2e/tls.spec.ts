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

// Check if we're in a local environment
const isLocalEnv = httpsPort === '8446' || httpsPort === '8447' || httpsPort === '8448';

for (const host of hosts) {
  test.describe(`TLS and redirect for ${host}`, () => {
    test(`HTTPS loads with valid cert: ${host}`, async ({ page, request }) => {
      if (isLocalEnv) {
        // Skip certificate validation in local environments
        // The certs are valid for production domains but we're accessing via localhost
        test.skip(true, 'Certificate validation not possible in local environment');
        return;
      }
      const res = await request.get(`https://${host}:${httpsPort}/`, { ignoreHTTPSErrors: false });
      expect(res.status()).toBe(200);
    });

    test(`HTTPS loads successfully (local): ${host}`, async ({ page, request }) => {
      if (!isLocalEnv) {
        test.skip(true, 'This test is for local environments only');
        return;
      }
      // For local testing, verify HTTPS works even if cert validation fails
      const res = await request.get(`https://${host}:${httpsPort}/`, { ignoreHTTPSErrors: true });
      expect(res.status()).toBe(200);
      
      // Verify security headers are present
      const headers = res.headers();
      expect(headers['strict-transport-security']).toBe('max-age=31536000; includeSubDomains');
      expect(headers['x-frame-options']).toBe('SAMEORIGIN');
      expect(headers['x-xss-protection']).toBe('1; mode=block');
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


