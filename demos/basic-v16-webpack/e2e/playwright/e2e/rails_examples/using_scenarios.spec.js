import { test } from '@playwright/test';

import { app, appScenario } from '../../support/on-rails';

test.describe('Rails using scenarios examples', () => {
  test.beforeEach(async ({ page: _page }) => {
    await app('clean');
  });

  test('setup basic scenario', async ({ page }) => {
    await appScenario('basic');
    await page.goto('/');
  });
});
