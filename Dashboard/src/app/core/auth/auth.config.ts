/**
 * Keycloak-Login fürs Dashboard (Checkliste A3).
 * Client "challengr-dashboard" im Realm "challengr": Public Client, Standard Flow, PKCE S256,
 * Redirect-URIs https://it220257.cloud.htl-leonding.ac.at/* und http://localhost:4200/*.
 * Nur Benutzer mit der Realm-Rolle "admin" bekommen vom Backend Daten.
 */
export const AUTH_CONFIG = {
  issuer: 'https://it220257.cloud.htl-leonding.ac.at/auth/realms/challengr',
  clientId: 'challengr-dashboard',
  scope: 'openid profile',
  adminRole: 'admin',
};
