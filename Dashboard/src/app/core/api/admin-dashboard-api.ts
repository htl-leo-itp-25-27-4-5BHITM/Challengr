import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { catchError, map, Observable, of, timeout } from 'rxjs';

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

/** Letzte Aktivität aus `GET /api/admin/overview` (keine Beispieldaten – bei Fehlern bleibt die Liste leer). */
@Injectable({ providedIn: 'root' })
export class AdminDashboardApi {
  constructor(private readonly http: HttpClient) {}

  getRecentActivity(): Observable<AuditEvent[]> {
    return this.http.get<AdminOverviewDto>('/api/admin/overview').pipe(
      timeout(6000),
      map((dto) => dto.auditEvents ?? []),
      catchError(() => of([])),
    );
  }
}
