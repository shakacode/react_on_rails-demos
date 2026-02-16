import { test, expect } from '@playwright/test';

test.describe('Hello World React Component', () => {
  test('should render and update greeting when input changes', async ({ page }) => {
    // Navigate to the hello_world page
    await page.goto('/hello_world');

    // Check that the page loaded correctly
    await expect(page.locator('h1')).toHaveText('Hello World');

    // Check initial greeting
    await expect(page.locator('text=Hello, Stranger!')).toBeVisible();

    // Find the input field
    const input = page.locator('input[type="text"]');
    await expect(input).toHaveValue('Stranger');

    // Clear the input and type a new name
    await input.clear();
    await input.fill('Friend');

    // Verify the greeting updates
    await expect(page.locator('text=Hello, Friend!')).toBeVisible();

    // Test another name
    await input.clear();
    await input.fill('World');
    await expect(page.locator('text=Hello, World!')).toBeVisible();
  });
});
