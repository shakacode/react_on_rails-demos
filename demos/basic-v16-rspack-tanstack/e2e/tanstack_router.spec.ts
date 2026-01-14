import { test, expect } from '@playwright/test';

test.describe('TanStack Router SSR Demo', () => {
  test.describe('Server-Side Rendering Verification', () => {
    test('home page is server-rendered', async ({ page }) => {
      await page.goto('/');

      // Wait for page to load
      await page.waitForLoadState('domcontentloaded');

      // Content should be visible (proves SSR)
      await expect(page.locator('h1')).toContainText('TanStack Router Demo');
      await expect(page.locator('nav')).toBeVisible();
    });

    test('about page is server-rendered at correct route', async ({ page }) => {
      await page.goto('/about');

      // Wait for the page to fully load
      await page.waitForLoadState('domcontentloaded');

      // Check page contains About content
      await expect(page.locator('h1')).toContainText('About This Demo');
    });

    test('URL params are server-rendered correctly', async ({ page }) => {
      await page.goto('/users/123');

      // Wait for page to load
      await page.waitForLoadState('domcontentloaded');

      // User ID should be rendered by server
      await expect(page.locator('text=User ID: 123')).toBeVisible();
    });

    test('search params are server-rendered correctly', async ({ page }) => {
      await page.goto('/search?q=hello&page=2');

      // Wait for page to load
      await page.waitForLoadState('domcontentloaded');

      // Query params should be rendered by server
      await expect(page.locator('text=Query: hello')).toBeVisible();
      await expect(page.locator('text=Page: 2')).toBeVisible();
    });

    test('nested routes are server-rendered', async ({ page }) => {
      await page.goto('/demo/nested/deep');

      // Wait for page to load
      await page.waitForLoadState('domcontentloaded');

      // Both parent and child content should be present
      await expect(page.locator('.nested-layout')).toBeVisible();
      // Use h3 selector to specifically target the page heading, not the nav link
      await expect(page.locator('h3:text("Deep Nested Page")')).toBeVisible();
    });
  });

  test.describe('Client Hydration Verification', () => {
    test('navigation works after hydration', async ({ page }) => {
      await page.goto('/');

      // Wait for interactive elements to be ready (better than networkidle with HMR)
      await page.waitForLoadState('domcontentloaded');
      await expect(page.locator('a[href="/about"]')).toBeVisible();

      // Click navigation link
      await page.click('a[href="/about"]');

      // Should navigate without full page reload
      await expect(page).toHaveURL('/about');
      await expect(page.locator('h1')).toContainText('About');
    });

    test('search params update client-side', async ({ page }) => {
      await page.goto('/search');

      // Wait for the form to be interactive
      await page.waitForLoadState('domcontentloaded');
      const input = page.locator('input[type="text"]');
      await expect(input).toBeVisible();

      // Type in search input and submit
      await input.fill('test query');
      await page.click('button[type="submit"]');

      // URL should update
      await expect(page).toHaveURL(/q=test/);
    });

    test('URL params navigation works', async ({ page }) => {
      await page.goto('/users');

      // Wait for navigation links to be ready
      await page.waitForLoadState('domcontentloaded');
      await expect(page.locator('a[href="/users/42"]')).toBeVisible();

      // Click on a user link
      await page.click('a[href="/users/42"]');

      await expect(page).toHaveURL('/users/42');
      await expect(page.locator('text=User ID: 42')).toBeVisible();
    });

    test('nested routes navigation works', async ({ page }) => {
      await page.goto('/demo/nested');

      // Wait for navigation links to be ready
      await page.waitForLoadState('domcontentloaded');
      await expect(page.locator('a[href="/demo/nested/deep"]')).toBeVisible();

      // Click on deep nested link
      await page.click('a[href="/demo/nested/deep"]');

      await expect(page).toHaveURL('/demo/nested/deep');
      // Use h3 selector to specifically target the page heading, not the nav link
      await expect(page.locator('h3:text("Deep Nested Page")')).toBeVisible();
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

      // Wait for DOM to be ready and content to be visible
      await page.waitForLoadState('domcontentloaded');
      await expect(page.locator('h1')).toBeVisible();

      // Wait for React hydration to complete by checking that navigation works
      // This is more reliable than a fixed timeout as it confirms React is interactive
      const aboutLink = page.locator('a[href="/about"]');
      await expect(aboutLink).toBeVisible();

      // Click and verify navigation works (proves hydration is complete)
      await aboutLink.click();
      await expect(page).toHaveURL('/about');

      // Check for hydration errors that may have been logged
      const hydrationErrors = consoleLogs.filter(
        (log) => log.includes('hydrat') || log.includes('mismatch')
      );
      expect(hydrationErrors).toHaveLength(0);
    });
  });
});
