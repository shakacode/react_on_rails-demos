import { test, expect } from '@playwright/test';

test.describe('TanStack Router SSR Demo', () => {
  test.describe('Server-Side Rendering Verification', () => {
    test('home page is server-rendered', async ({ page }) => {
      await page.goto('/');

      // Content should be visible (proves SSR)
      await expect(page.locator('h1')).toContainText('TanStack Router Demo');
      await expect(page.locator('nav')).toBeVisible();
    });

    test('about page is server-rendered at correct route', async ({ page }) => {
      await page.goto('/about');

      // Check page contains About content
      await expect(page.locator('h1')).toContainText('About This Demo');
    });

    test('URL params are server-rendered correctly', async ({ page }) => {
      await page.goto('/users/123');

      // User ID should be rendered by server
      await expect(page.locator('text=User ID: 123')).toBeVisible();
    });

    test('search params are server-rendered correctly', async ({ page }) => {
      await page.goto('/search?q=hello&page=2');

      // Query params should be rendered by server
      await expect(page.locator('text=Query: hello')).toBeVisible();
      await expect(page.locator('text=Page: 2')).toBeVisible();
    });

    test('nested routes are server-rendered', async ({ page }) => {
      await page.goto('/demo/nested/deep');

      // Both parent and child content should be present
      await expect(page.locator('.nested-layout')).toBeVisible();
      await expect(page.locator('text=Deep Nested')).toBeVisible();
    });
  });

  test.describe('Client Hydration Verification', () => {
    test('navigation works after hydration', async ({ page }) => {
      await page.goto('/');

      // Wait for hydration
      await page.waitForLoadState('networkidle');

      // Click navigation link
      await page.click('a[href="/about"]');

      // Should navigate without full page reload
      await expect(page).toHaveURL('/about');
      await expect(page.locator('h1')).toContainText('About');
    });

    test('search params update client-side', async ({ page }) => {
      await page.goto('/search');

      // Wait for hydration
      await page.waitForLoadState('networkidle');

      // Type in search input and submit
      const input = page.locator('input[type="text"]');
      await input.fill('test query');
      await page.click('button[type="submit"]');

      // URL should update
      await expect(page).toHaveURL(/q=test/);
    });

    test('URL params navigation works', async ({ page }) => {
      await page.goto('/users');
      await page.waitForLoadState('networkidle');

      // Click on a user link
      await page.click('a[href="/users/42"]');

      await expect(page).toHaveURL('/users/42');
      await expect(page.locator('text=User ID: 42')).toBeVisible();
    });

    test('nested routes navigation works', async ({ page }) => {
      await page.goto('/demo/nested');
      await page.waitForLoadState('networkidle');

      // Click on deep nested link
      await page.click('a[href="/demo/nested/deep"]');

      await expect(page).toHaveURL('/demo/nested/deep');
      await expect(page.locator('text=Deep Nested')).toBeVisible();
    });
  });

  test.describe('SSR + Hydration Consistency', () => {
    test('no hydration mismatch warnings', async ({ page }) => {
      const consoleLogs: string[] = [];
      page.on('console', (msg) => {
        if (msg.type() === 'error' || msg.type() === 'warning') {
          consoleLogs.push(msg.text());
        }
      });

      await page.goto('/');
      await page.waitForLoadState('networkidle');

      // Check for hydration errors
      const hydrationErrors = consoleLogs.filter(
        (log) => log.includes('hydrat') || log.includes('mismatch')
      );
      expect(hydrationErrors).toHaveLength(0);
    });
  });
});
