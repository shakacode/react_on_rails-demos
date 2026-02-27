import { test, expect } from '@playwright/test';

test.describe('Hello Server RSC demo', () => {
  test('renders the RSC page and hydrates LikeButton', async ({ page }) => {
    await page.goto('/hello_server');

    await expect(page.locator('h1')).toHaveText('React Server Components Demo');
    await expect(page.locator('h2')).toContainText('Hello, React on Rails Pro!');

    const likeButton = page.getByRole('button', { name: '👍 Like' });
    await expect(likeButton).toBeVisible();
    await expect(page.locator('text=0 likes')).toBeVisible();

    await likeButton.click();
    await expect(page.locator('text=1 like')).toBeVisible();
  });
});
