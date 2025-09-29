// Playwright helpers for React on Rails demos

export async function waitForReactOnRails(page) {
  await page.waitForFunction(() => window.ReactOnRails !== undefined);
}

export async function getReactProps(page, componentName) {
  return await page.evaluate((name) => {
    const component = window.ReactOnRails?.getComponent(name);
    return component ? component.props : null;
  }, componentName);
}

export async function waitForTurbo(page) {
  await page.waitForFunction(() => window.Turbo !== undefined);
}

export async function getCsrfToken(page) {
  return await page.getAttribute('meta[name="csrf-token"]', 'content');
}

export async function login(page, email = 'test@example.com', password = 'password') {
  await page.goto('/login');
  await page.fill('input[name="email"]', email);
  await page.fill('input[name="password"]', password);
  await page.locator('form').submit();
  await page.waitForURL((url) => !url.pathname.includes('/login'));
}

export async function resetDatabase(page, baseURL) {
  const response = await page.request.post(`${baseURL}/cypress/reset_database`);
  return response.ok();
}

export async function createFactory(page, baseURL, factoryName, attributes = {}) {
  const response = await page.request.post(`${baseURL}/cypress/factories`, {
    data: {
      factory: factoryName,
      attributes: attributes,
    },
  });
  return response.json();
}