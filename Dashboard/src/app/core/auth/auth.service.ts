import { Injectable, PLATFORM_ID, inject } from '@angular/core';
import { isPlatformBrowser } from '@angular/common';
import { AUTH_CONFIG } from './auth.config';

interface TokenResponse {
  access_token: string;
  refresh_token?: string;
  id_token?: string;
  expires_in?: number;
}

const STORAGE_KEY = 'challengr.dashboard.auth';
const VERIFIER_KEY = 'challengr.dashboard.pkce';

/**
 * Keycloak-Login (Authorization Code + PKCE) ohne zusätzliche Bibliothek.
 * Tokens liegen nur in der sessionStorage des Tabs (weg, sobald der Tab zu ist).
 */
@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly browser = isPlatformBrowser(inject(PLATFORM_ID));
  private accessToken: string | null = null;
  private refreshToken: string | null = null;
  private idToken: string | null = null;
  private expiresAt = 0;
  private refreshing: Promise<boolean> | null = null;

  /** Beim Start: Code aus dem Redirect einlösen oder gespeicherten Login laden, sonst zum Login. */
  async init(): Promise<void> {
    if (!this.browser) return;
    const url = new URL(window.location.href);
    const code = url.searchParams.get('code');
    if (code) {
      await this.exchangeCode(code);
      url.searchParams.delete('code');
      url.searchParams.delete('state');
      url.searchParams.delete('session_state');
      url.searchParams.delete('iss');
      window.history.replaceState({}, '', url.pathname + url.search + url.hash);
    } else {
      this.load();
    }
    if (!this.accessToken) {
      await this.login();
    }
  }

  get isLoggedIn(): boolean {
    return !!this.accessToken;
  }

  /** Anzeigename aus dem Token */
  get userName(): string {
    return (this.claims()['preferred_username'] as string) ?? '';
  }

  get isAdmin(): boolean {
    const roles = (this.claims()['realm_access'] as { roles?: string[] } | undefined)?.roles ?? [];
    return roles.includes(AUTH_CONFIG.adminRole);
  }

  /** Gültiges Access-Token (erneuert es kurz vor Ablauf). */
  async token(): Promise<string | null> {
    if (!this.accessToken) return null;
    if (Date.now() > this.expiresAt - 30_000) {
      const ok = await this.refresh();
      if (!ok) return null;
    }
    return this.accessToken;
  }

  async login(): Promise<void> {
    if (!this.browser) return;
    const verifier = randomString(64);
    sessionStorage.setItem(VERIFIER_KEY, verifier);
    const params = new URLSearchParams({
      response_type: 'code',
      client_id: AUTH_CONFIG.clientId,
      redirect_uri: this.redirectUri(),
      scope: AUTH_CONFIG.scope,
      state: randomString(16),
      code_challenge: await sha256Base64Url(verifier),
      code_challenge_method: 'S256',
    });
    window.location.assign(`${AUTH_CONFIG.issuer}/protocol/openid-connect/auth?${params}`);
  }

  logout(): void {
    if (!this.browser) return;
    const idToken = this.idToken;
    this.clear();
    const params = new URLSearchParams({ post_logout_redirect_uri: this.redirectUri(), client_id: AUTH_CONFIG.clientId });
    if (idToken) params.set('id_token_hint', idToken);
    window.location.assign(`${AUTH_CONFIG.issuer}/protocol/openid-connect/logout?${params}`);
  }

  async refresh(): Promise<boolean> {
    if (!this.refreshToken) return false;
    if (!this.refreshing) {
      this.refreshing = this.requestToken({
        grant_type: 'refresh_token',
        client_id: AUTH_CONFIG.clientId,
        refresh_token: this.refreshToken,
      }).finally(() => (this.refreshing = null));
    }
    return this.refreshing;
  }

  private async exchangeCode(code: string): Promise<void> {
    const verifier = sessionStorage.getItem(VERIFIER_KEY) ?? '';
    sessionStorage.removeItem(VERIFIER_KEY);
    await this.requestToken({
      grant_type: 'authorization_code',
      client_id: AUTH_CONFIG.clientId,
      code,
      redirect_uri: this.redirectUri(),
      code_verifier: verifier,
    });
  }

  private async requestToken(body: Record<string, string>): Promise<boolean> {
    try {
      const res = await fetch(`${AUTH_CONFIG.issuer}/protocol/openid-connect/token`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams(body),
      });
      if (!res.ok) {
        this.clear();
        return false;
      }
      this.apply((await res.json()) as TokenResponse);
      return true;
    } catch {
      return false;
    }
  }

  private apply(t: TokenResponse): void {
    this.accessToken = t.access_token;
    this.refreshToken = t.refresh_token ?? this.refreshToken;
    this.idToken = t.id_token ?? this.idToken;
    this.expiresAt = Date.now() + (t.expires_in ?? 60) * 1000;
    sessionStorage.setItem(STORAGE_KEY, JSON.stringify({
      accessToken: this.accessToken, refreshToken: this.refreshToken, idToken: this.idToken, expiresAt: this.expiresAt,
    }));
  }

  private load(): void {
    try {
      const saved = JSON.parse(sessionStorage.getItem(STORAGE_KEY) ?? 'null');
      if (saved?.accessToken) {
        this.accessToken = saved.accessToken;
        this.refreshToken = saved.refreshToken;
        this.idToken = saved.idToken;
        this.expiresAt = saved.expiresAt ?? 0;
      }
    } catch {
      this.clear();
    }
  }

  private clear(): void {
    this.accessToken = this.refreshToken = this.idToken = null;
    this.expiresAt = 0;
    if (this.browser) sessionStorage.removeItem(STORAGE_KEY);
  }

  private claims(): Record<string, unknown> {
    if (!this.accessToken) return {};
    try {
      const payload = this.accessToken.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
      return JSON.parse(decodeURIComponent(escape(atob(payload))));
    } catch {
      return {};
    }
  }

  private redirectUri(): string {
    return `${window.location.origin}/`;
  }
}

function randomString(length: number): string {
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  return base64Url(bytes);
}

async function sha256Base64Url(text: string): Promise<string> {
  const hash = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return base64Url(new Uint8Array(hash));
}

function base64Url(bytes: Uint8Array): string {
  let s = '';
  bytes.forEach((b) => (s += String.fromCharCode(b)));
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
