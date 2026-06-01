import { Component } from '@angular/core';
import { AdminDashboardApi, AuditEvent, DashboardKpi, SetupWarning } from '../../core/api/admin-dashboard-api';
import { finalize } from 'rxjs';

@Component({
  selector: 'app-dashboard',
  standalone: false,
  templateUrl: './dashboard.html',
  styleUrl: './dashboard.css',
})
export class Dashboard {
  kpis: DashboardKpi[] = [];
  setupWarnings: SetupWarning[] = [];
  auditEvents: AuditEvent[] = [];

  loading = true;
  error: string | null = null;

  constructor(private readonly api: AdminDashboardApi) {
    this.reload();
  }

  reload() {
    this.loading = true;
    this.error = null;

    this.api
      .getOverview()
      .pipe(
        finalize(() => {
          this.loading = false;
        }),
      )
      .subscribe({
        next: (dto) => {
          this.kpis = dto.kpis;
          this.setupWarnings = dto.setupWarnings;
          this.auditEvents = dto.auditEvents;
        },
        error: (err) => {
          // This should be rare because the API layer falls back to mock data.
          this.error = err?.message ?? 'Failed to load overview';
        },
      });
  }
}
