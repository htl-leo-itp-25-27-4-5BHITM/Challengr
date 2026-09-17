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
        { label: 'Battles (heute / gesamt)', value: '14 / 892', tone: 'info', icon: '⚔️' },
        { label: 'Challenges im Katalog', value: '47', tone: 'primary', icon: '🏆' },
        { label: 'Shop-Käufe gesamt', value: '63', tone: 'info', icon: '🛍️' },
        { label: 'Beliebteste Kategorie', value: 'Mutprobe', tone: 'primary', icon: '🔥' },
        { label: 'Top Spieler', value: 'test (399 P.)', tone: 'warning', icon: '👑' },
      ],
      setupWarnings: [
        { title: 'Backend & Datenbank', detail: 'Nicht erreichbar – zeige Beispieldaten', tone: 'warn' },
      ],
      auditEvents: [
        { type: 'BATTLE', detail: 'test gewinnt eine Mutprobe-Challenge', at: '27.05.2026, 13:57' },
        { type: 'SHOP', detail: 'cookieclicker kauft Streak Saver', at: '27.05.2026, 11:26' },
        { type: 'BATTLE', detail: 'cookieclicker gewinnt eine Fitness-Challenge', at: '26.05.2026, 13:08' },
        { type: 'SHOP', detail: 'test kauft Point Shield', at: '26.05.2026, 11:23' },
      ],
    };
  }
}
