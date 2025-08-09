import { test, expect } from '@playwright/test';

type RouteCase = { host: string; path: string; mustContain?: string; };

const httpsPort = process.env.BASE_HTTPS || '8446';

const cases: RouteCase[] = [
  { host: 'iLegalFlow.com', path: '/', mustContain: 'iLegalFlow' },
  { host: 'VW.iLegalFlow.com', path: '/', mustContain: 'Vault' },
  { host: 'Crypto-Fakes.com', path: '/', mustContain: 'Crypto' },
  { host: 'cutietraders.com', path: '/', mustContain: 'Cutie' },
  { host: 'CutieTraders.com', path: '/', mustContain: 'Cutie' },
  { host: 'iMediFlow.com', path: '/', mustContain: 'Medi' },
];

for (const c of cases) {
  test.describe(`Routing for ${c.host}`, () => {
    test(`GET ${c.path} on ${c.host}`, async ({ page }) => {
      await page.goto(`https://${c.host}:${httpsPort}${c.path}`);
      await expect(page).toHaveTitle(/.+/);
      if (c.mustContain) {
        await expect(page.locator('body')).toContainText(new RegExp(c.mustContain, 'i'));
      }
    });
  });
}


