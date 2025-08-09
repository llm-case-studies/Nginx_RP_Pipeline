import { test, expect } from '@playwright/test';

const httpsPort = process.env.BASE_HTTPS || '8446';

test.describe('SPA fallback behavior', () => {
  test('Deep link returns index.html', async ({ page }) => {
    const host = 'iLegalFlow.com';
    await page.goto(`https://${host}:${httpsPort}/some/deep/link`);
    await expect(page.locator('body')).toContainText(/(iLegalFlow|Flow)/i);
  });
});


