import { ChangeDetectorRef, Component, OnInit } from '@angular/core';
import { HttpClient } from '@angular/common/http';

export interface PlayerReport {
  id: number;
  reporterId: string;
  reporterName: string | null;
  reportedId: string;
  reportedName: string | null;
  reason: string;
  comment: string | null;
  status: 'OPEN' | 'RESOLVED';
  createdAt: string;
  reportedBanUntil: string | null;
}

const REASONS: Record<string, string> = {
  BELEIDIGUNG: 'Beleidigung',
  UNPASSENDER_NAME: 'Unpassender Name',
  BELAESTIGUNG: 'Belästigung',
  BETRUG: 'Schummeln / Betrug',
  SONSTIGES: 'Sonstiges',
};

/** Meldungen aus der App (Checkliste B2): ansehen, Spieler sperren, erledigen. */
@Component({
  selector: 'app-reports',
  standalone: false,
  templateUrl: './reports.html',
  styleUrls: ['../users/users.css', './reports.css'],
})
export class Reports implements OnInit {
  reports: PlayerReport[] = [];
  showAll = false;
  busyId: number | null = null;
  error: string | null = null;

  constructor(private http: HttpClient, private cd: ChangeDetectorRef) {}

  ngOnInit(): void {
    this.load();
  }

  load(): void {
    this.error = null;
    this.http.get<PlayerReport[]>(`/api/admin/reports?status=${this.showAll ? 'ALL' : 'OPEN'}`).subscribe({
      next: (data) => {
        this.reports = data;
        this.cd.detectChanges();
      },
      error: () => {
        this.error = 'Meldungen konnten nicht geladen werden (Admin-Login?)';
        this.cd.detectChanges();
      },
    });
  }

  toggleAll(): void {
    this.showAll = !this.showAll;
    this.load();
  }

  reasonText(reason: string): string {
    return REASONS[reason] ?? reason;
  }

  isBanned(r: PlayerReport): boolean {
    return !!r.reportedBanUntil && new Date(r.reportedBanUntil).getTime() > Date.now();
  }

  ban(r: PlayerReport, hours: number): void {
    this.busyId = r.id;
    this.http
      .post<{ banUntil: string }>(`/api/admin/players/${encodeURIComponent(r.reportedId)}/ban`, {
        durationSeconds: hours * 3600,
        reason: `Meldung: ${this.reasonText(r.reason)}`,
      })
      .subscribe({
        next: (res) => {
          r.reportedBanUntil = res?.banUntil ?? null;
          this.busyId = null;
          this.cd.detectChanges();
        },
        error: () => {
          this.busyId = null;
          this.error = 'Sperren fehlgeschlagen';
          this.cd.detectChanges();
        },
      });
  }

  resolve(r: PlayerReport): void {
    this.busyId = r.id;
    this.http.post<PlayerReport>(`/api/admin/reports/${r.id}/resolve`, {}).subscribe({
      next: () => {
        this.busyId = null;
        this.load();
      },
      error: () => {
        this.busyId = null;
        this.error = 'Konnte nicht als erledigt markiert werden';
        this.cd.detectChanges();
      },
    });
  }
}
