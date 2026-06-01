import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { catchError, Observable, of, timeout } from 'rxjs';

export type KpiTone = 'primary' | 'info' | 'warning' | 'danger';

export interface DashboardKpi {
  label: string;
  value: string;
  tone: KpiTone;
  icon: string;
}

export type WarningTone = 'ok' | 'warn';

export interface SetupWarning {
  title: string;
  detail: string;
  tone: WarningTone;
}

export interface AuditEvent {
  type: string;
  detail: string;
  at: string;
}

export interface AdminOverviewDto {
  kpis: DashboardKpi[];
  setupWarnings: SetupWarning[];
  auditEvents: AuditEvent[];
}

/**
 * Lightweight API wrapper for the admin overview.
 *
 * Backend endpoint is optional. If it’s not available yet, we fall back to mock data.
 */
@Injectable({ providedIn: 'root' })
export class AdminDashboardApi {
  constructor(private readonly http: HttpClient) {}

  // If you later add a backend endpoint, just make this return that DTO.
  // Example could be: GET /api/admin/overview
  getOverview(): Observable<AdminOverviewDto> {
    return this.http.get<AdminOverviewDto>('/api/admin/overview').pipe(
      timeout(4000),
      catchError(() => of(this.getMockOverview())),
    );
  }

  /** fallback until backend is wired */
  private getMockOverview(): AdminOverviewDto {
    return {
      kpis: [
        { label: 'Spieler (aktiv/gesamt)', value: '182 / 614', tone: 'primary', icon: '👥' },
        { label: 'Aktive Bans', value: '2', tone: 'danger', icon: '⛔' },
      ],
      setupWarnings: [
        { title: 'Keycloak', detail: 'Realm reachable, token flow OK', tone: 'ok' },
        { title: 'Database', detail: 'Connection stable, migrations up-to-date', tone: 'ok' },
        { title: 'Websocket / Game', detail: '1 instance restarting (investigate)', tone: 'warn' },
        { title: 'Reports', detail: '4 items need review', tone: 'warn' },
      ],
      auditEvents: [
        { type: 'BAN', detail: 'User 9b2a… banned for 7 days', at: '27.05.2026, 13:57' },
        { type: 'UNBAN', detail: 'User 22ac… unbanned', at: '27.05.2026, 11:26' },
        { type: 'STORE', detail: 'Updated item price: Turbo-Start', at: '26.05.2026, 13:08' },
        { type: 'CHALLENGE', detail: 'Created category: Event (Battle Royale)', at: '26.05.2026, 11:23' },
      ],
    };
  }
}
