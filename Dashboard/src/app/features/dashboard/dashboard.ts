import { ChangeDetectorRef, Component } from '@angular/core';
import { AdminDashboardApi, AuditEvent } from '../../core/api/admin-dashboard-api';
import { AdminStats, AdminStatsApi } from '../../core/api/admin-stats-api';
import { ChartSeries } from './charts';

/** Übersicht mit echten Spieldaten: Kennzahlen, Verläufe, Verteilungen, Top 10, letzte Aktivität. */
@Component({
  selector: 'app-dashboard',
  standalone: false,
  templateUrl: './dashboard.html',
  styleUrl: './dashboard.css',
})
export class Dashboard {
  readonly ranges = [7, 30, 90];
  days = 30;

  stats: AdminStats | null = null;
  activity: AuditEvent[] = [];
  loading = true;
  error: string | null = null;

  // vorbereitete Diagrammdaten
  dayLabels: string[] = [];
  playerSeries: ChartSeries[] = [];
  battleSeries: ChartSeries[] = [];
  hourLabels: string[] = [];
  hourSeries: ChartSeries[] = [];
  rankColor = 'var(--series-single)';

  constructor(
    private readonly statsApi: AdminStatsApi,
    private readonly overviewApi: AdminDashboardApi,
    private readonly cd: ChangeDetectorRef,
  ) {
    this.reload();
  }

  setRange(days: number): void {
    if (days === this.days) return;
    this.days = days;
    this.reload();
  }

  reload(): void {
    this.loading = true;
    this.error = null;
    this.statsApi.get(this.days).subscribe({
      next: (s) => {
        this.stats = s;
        this.prepare(s);
        this.loading = false;
        this.cd.detectChanges();
      },
      error: (err) => {
        this.loading = false;
        this.error = err?.status === 403
          ? 'Dieses Konto hat keine Admin-Rolle.'
          : 'Die Daten konnten nicht geladen werden – ist das Backend erreichbar?';
        this.cd.detectChanges();
      },
    });
    this.overviewApi.getRecentActivity().subscribe((events) => {
      this.activity = events;
      this.cd.detectChanges();
    });
  }

  private prepare(s: AdminStats): void {
    this.dayLabels = s.daily.map((d) => d.day);
    this.playerSeries = [
      { name: 'Aktive Spieler', color: 'var(--series-single)', values: s.daily.map((d) => d.activePlayers) },
      { name: 'Neue Spieler', color: 'var(--series-3)', values: s.daily.map((d) => d.newPlayers) },
    ];
    this.battleSeries = [
      { name: 'Quiz-Show', color: 'var(--series-1)', values: s.daily.map((d) => d.quiz) },
      { name: 'Real-Life', color: 'var(--series-2)', values: s.daily.map((d) => d.realLife) },
      { name: 'Friendly', color: 'var(--series-3)', values: s.daily.map((d) => d.friendly) },
    ];
    this.hourLabels = s.battlesByHour.map((_, h) => String(h));
    this.hourSeries = [{ name: 'Battles', color: 'var(--series-single)', values: s.battlesByHour }];
  }

  get battlesInRange(): number {
    return this.stats?.modes.reduce((sum, m) => sum + m.count, 0) ?? 0;
  }

  /** Anteil der Herausforderungen, die wirklich gespielt wurden */
  get playedRate(): string {
    const all = this.stats?.outcomes.reduce((s, o) => s + o.count, 0) ?? 0;
    const done = this.stats?.outcomes.find((o) => o.name === 'Gespielt')?.count ?? 0;
    return all ? `${Math.round((done / all) * 100)} %` : '–';
  }

  get peakHour(): string {
    const h = this.stats?.battlesByHour ?? [];
    const max = Math.max(0, ...h);
    return max ? `${h.indexOf(max)}–${h.indexOf(max) + 1} Uhr` : '–';
  }

  winRate(r: { battles: number; wins: number }): string {
    return r.battles ? `${Math.round((r.wins / r.battles) * 100)} %` : '–';
  }

  lastSeen(iso: string | null): string {
    if (!iso) return '–';
    const mins = Math.round((Date.now() - new Date(iso).getTime()) / 60000);
    if (mins < 5) return 'gerade aktiv';
    if (mins < 60) return `vor ${mins} min`;
    const h = Math.round(mins / 60);
    if (h < 24) return `vor ${h} h`;
    const d = Math.round(h / 24);
    return d === 1 ? 'vor 1 Tag' : `vor ${d} Tagen`;
  }

  eventIcon(type: string): string {
    return type === 'BATTLE' ? '⚔️' : type === 'SHOP' ? '🛍️' : type === 'REPORT' ? '🚩' : '•';
  }
}
