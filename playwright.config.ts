import { defineConfig, devices } from '@playwright/test';

// Domains to test behind the proxy
const hosts = [
  'iLegalFlow.com',
  'VW.iLegalFlow.com',
  'Crypto-Fakes.com',
  'cutietraders.com',
  'CutieTraders.com',
  'iMediFlow.com',
];

// Map test env
const BASE_HTTP = process.env.BASE_HTTP || '8083';
const BASE_HTTPS = process.env.BASE_HTTPS || '8446';
const DEFAULT_HOST = process.env.DEFAULT_HOST || hosts[0];
const BASE_URL = process.env.BASE_URL || `https://${DEFAULT_HOST}:${BASE_HTTPS}`;

// Chromium-only local resolver overrides for ship env
const hostResolverRules = hosts.map(h => `MAP ${h} 127.0.0.1`).join(',');

export default defineConfig({
  testDir: 'tests/e2e',
  timeout: 30_000,
  expect: { timeout: 5_000 },
  reporter: [['list']],
  use: {
    baseURL: BASE_URL,
    ignoreHTTPSErrors: true,
    trace: 'on-first-retry',
  },
  projects: [
    {
      name: 'chromium-ship',
      use: {
        browserName: 'chromium',
        ignoreHTTPSErrors: true,
        launchOptions: {
          args: [
            `--host-resolver-rules=${hostResolverRules}`,
            '--ignore-certificate-errors',
            '--ignore-ssl-errors',
            '--ignore-certificate-errors-spki-list',
          ],
        },
      },
    },
  ],
});


