import { TestBed } from '@angular/core/testing';
import { AuthService } from './auth.service';

/** Erzeugt ein (unsigniertes) Test-JWT mit den gewünschten Claims. */
function jwt(claims: Record<string, unknown>): string {
  const enc = (o: unknown) => btoa(JSON.stringify(o)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  return `${enc({ alg: 'none' })}.${enc(claims)}.sig`;
}

describe('AuthService', () => {
  beforeEach(() => sessionStorage.clear());

  function withToken(claims: Record<string, unknown>): AuthService {
    sessionStorage.setItem('challengr.dashboard.auth', JSON.stringify({
      accessToken: jwt(claims), refreshToken: 'r', expiresAt: Date.now() + 300_000,
    }));
    const auth = TestBed.inject(AuthService);
    (auth as unknown as { load: () => void }).load();
    return auth;
  }

  it('erkennt Admins an der Realm-Rolle', () => {
    const auth = withToken({ preferred_username: 'lehrer', realm_access: { roles: ['admin', 'offline_access'] } });
    expect(auth.isLoggedIn).toBe(true);
    expect(auth.isAdmin).toBe(true);
    expect(auth.userName).toBe('lehrer');
  });

  it('normale Spieler sind keine Admins', () => {
    const auth = withToken({ preferred_username: 'schueler', realm_access: { roles: ['offline_access'] } });
    expect(auth.isAdmin).toBe(false);
  });

  it('ohne Login gibt es kein Token', async () => {
    const auth = TestBed.inject(AuthService);
    expect(auth.isLoggedIn).toBe(false);
    expect(await auth.token()).toBeNull();
  });
});
