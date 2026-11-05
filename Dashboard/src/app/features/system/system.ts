import { ChangeDetectorRef, Component, OnDestroy, OnInit } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { ACTIONS, AuditRow } from '../users/users';

interface Check { name: string; state: 'ok' | 'warn' | 'error' | 'off'; detail: string; }
interface Status { checkedAt: string; startedAt: string; uptimeSeconds: number; online: number; players: number; landmarks: number; landmarkTiles: number; checks: Check[]; }
interface BackupFile { name: string; sizeBytes: number; createdAt: string; automatic: boolean; }
interface BackupOverview { available: boolean; lastSuccess: string | null; lastError: string | null; files: BackupFile[]; }
interface Announcement { id: number; text: string; startsAt: string | null; endsAt: string | null; active: boolean; showing: boolean; createdAt: string; createdBy: string | null; }

/** System: Status, Backups, Ankündigung in der App, Admin-Protokoll. */
@Component({
  selector: 'app-system',
  standalone: false,
  templateUrl: './system.html',
  styleUrls: ['../admin-tools.css'],
})
export class System implements OnInit, OnDestroy {
  status: Status | null = null;
  backups: BackupOverview | null = null;
  announcements: Announcement[] = [];
  audit: AuditRow[] = [];
  error: string | null = null;
  backupBusy = false;
  backupMsg: string | null = null;
  annText = '';
  annEnd = '';
  annMsg: string | null = null;
  private timer: any;

  constructor(private http: HttpClient, private cd: ChangeDetectorRef) {}

  ngOnInit(): void {
    this.loadAll();
    if (typeof window !== 'undefined') this.timer = setInterval(() => this.loadStatus(), 30_000);
  }

  ngOnDestroy(): void { clearInterval(this.timer); }

  loadAll(): void {
    this.loadStatus();
    this.http.get<BackupOverview>('/api/admin/backups').subscribe({ next: (b) => { this.backups = b; this.cd.markForCheck(); }, error: () => {} });
    this.http.get<Announcement[]>('/api/admin/announcements').subscribe({ next: (a) => { this.announcements = a; this.cd.markForCheck(); }, error: () => {} });
    this.http.get<AuditRow[]>('/api/admin/audit?limit=60').subscribe({ next: (a) => { this.audit = a; this.cd.markForCheck(); }, error: () => {} });
  }

  loadStatus(): void {
    this.http.get<Status>('/api/admin/status').subscribe({
      next: (s) => { this.status = s; this.error = null; this.cd.markForCheck(); },
      error: (e) => { this.error = e?.status === 403 ? 'Keine Admin-Rolle.' : 'Server antwortet nicht.'; this.cd.markForCheck(); },
    });
  }

  uptime(sec: number): string {
    const h = Math.floor(sec / 3600), d = Math.floor(h / 24);
    return d > 0 ? `${d} Tage ${h % 24} h` : h > 0 ? `${h} h ${Math.floor((sec % 3600) / 60)} min` : `${Math.floor(sec / 60)} min`;
  }

  size(b: number): string { return b > 1_000_000 ? (b / 1_000_000).toFixed(1) + ' MB' : Math.max(1, Math.round(b / 1000)) + ' KB'; }

  backupNow(): void {
    this.backupBusy = true;
    this.backupMsg = 'Backup läuft …';
    this.http.post<BackupFile>('/api/admin/backups', {}).subscribe({
      next: (f) => { this.backupBusy = false; this.backupMsg = `Fertig: ${f.name}`; this.loadAll(); },
      error: (e) => { this.backupBusy = false; this.backupMsg = e?.error?.message ?? 'Backup fehlgeschlagen.'; this.cd.markForCheck(); },
    });
  }

  /** Mit Login-Token herunterladen (ein normaler Link hätte keinen). */
  download(f: BackupFile): void {
    this.http.get(`/api/admin/backups/${encodeURIComponent(f.name)}`, { responseType: 'blob' }).subscribe((blob) => {
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = f.name;
      a.click();
      setTimeout(() => URL.revokeObjectURL(url), 5000);
    });
  }

  get currentAnnouncement(): Announcement | undefined { return this.announcements.find((a) => a.active); }

  announce(): void {
    const body = { text: this.annText.trim(), endsAt: this.annEnd ? new Date(this.annEnd).toISOString() : null };
    this.http.post<Announcement>('/api/admin/announcements', body).subscribe({
      next: () => { this.annText = ''; this.annEnd = ''; this.annMsg = 'Ankündigung ist aktiv – Spieler sehen sie beim nächsten Öffnen der App.'; this.loadAll(); },
      error: (e) => { this.annMsg = e?.error?.message ?? e?.error ?? 'Speichern fehlgeschlagen.'; this.cd.markForCheck(); },
    });
  }

  endAnnouncement(a: Announcement): void {
    this.http.delete(`/api/admin/announcements/${a.id}`).subscribe(() => { this.annMsg = 'Beendet.'; this.loadAll(); });
  }

  actionText(a: string): string { return ACTIONS[a] ?? a; }
}
