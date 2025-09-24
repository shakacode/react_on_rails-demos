// Cypress custom commands for React on Rails demos

// Command to wait for React on Rails to be ready
Cypress.Commands.add('waitForReactOnRails', () => {
  cy.window().should('have.property', 'ReactOnRails');
});

// Command to get React component props
Cypress.Commands.add('getReactProps', (componentName) => {
  return cy.window().then((win) => {
    const component = win.ReactOnRails.getComponent(componentName);
    return component ? component.props : null;
  });
});

// Command to check if turbo is loaded
Cypress.Commands.add('waitForTurbo', () => {
  cy.window().should('have.property', 'Turbo');
});

// Command for Rails CSRF token
Cypress.Commands.add('getCsrfToken', () => {
  return cy
    .get('meta[name="csrf-token"]')
    .should('have.attr', 'content')
    .then((content) => content);
});

// Command to login (customize based on your auth)
Cypress.Commands.add('login', (email = 'test@example.com', password = 'password') => {
  cy.visit('/login');
  cy.get('input[name="email"]').type(email);
  cy.get('input[name="password"]').type(password);
  cy.get('form').submit();
  cy.url().should('not.include', '/login');
});

// Command to reset database (requires Rails endpoint)
Cypress.Commands.add('resetDatabase', () => {
  cy.request('POST', '/cypress/reset_database');
});

// Command to create factory data (requires Rails endpoint)
Cypress.Commands.add('createFactory', (factoryName, attributes = {}) => {
  return cy.request('POST', '/cypress/factories', {
    factory: factoryName,
    attributes: attributes,
  });
});