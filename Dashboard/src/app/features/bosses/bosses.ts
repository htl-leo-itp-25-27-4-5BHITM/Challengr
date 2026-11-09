import { ChangeDetectorRef, Component, OnDestroy, OnInit } from '@angular/core';
import { HttpClient } from '@angular/common/http';

interface Boss { id: number; name: string; place: string; latitude: number; longitude: number; hp: number; maxHp: number; phase: string; fighters: number; minFighters: number; expiresAt: string; fightEndsAt: string | null; }
interface Candidate { id: string; name: string; online: boolean; lastSeenAt: string; character: string | null; }
interface Checkpoint { id: string; name: string; latitude: number; longitude: number; expiresAt: string; }

const PHASES: Record<string, string> = { WAITING: 'wartet auf Kämpfer', FIGHT: 'Kampf läuft', RAGE: 'Raserei', FINALE: 'Finale' };

/** Riss-Wächter: offene Risse sehen und schließen, einen Riss bei einem Spieler öffnen. */
@Component({
  selector: 'app-bosses',
  standalone: false,
  templateUrl: './bosses.html',
  styleUrls: ['../admin-tools.css', './bosses.css'],
})
export class Bosses implements OnInit, OnDestroy {
  bosses: Boss[] = [];
  checkpoints: Checkpoint[] = [];
  players: Candidate[] = [];
  search = '';
  onlyOnline = false;
  busyId: string | null = null;
  msg: string | null = null;
  error: string | null = null;
  private timer: any;

  constructor(private http: HttpClient, private cd: ChangeDetectorRef) {}

  ngOnInit(): void {
    this.loadAll();
    if (typeof window !== 'undefined') this.timer = setInterval(() => this.loadBosses(), 10_000);
  }

  ngOnDestroy(): void { clearInterval(this.timer); }

  loadAll(): void {
    this.loadBosses();
    this.http.get<Candidate[]>('/api/admin/bosses/players').subscribe({
      next: (p) => { this.players = p; this.cd.markForCheck(); },
      error: (e) => { this.error = e?.status === 403 ? 'Keine Admin-Rolle.' : 'Spieler konnten nicht geladen werden.'; this.cd.markForCheck(); },
    });
  }

  loadBosses(): void {
    this.http.get<Boss[]>('/api/admin/bosses').subscribe({ next: (b) => { this.bosses = b; this.cd.markForCheck(); }, error: () => {} });
    this.http.get<Checkpoint[]>('/api/admin/bosses/checkpoints').subscribe({ next: (c) => { this.checkpoints = c; this.cd.markForCheck(); }, error: () => {} });
  }

  get filtered(): Candidate[] {
    const q = this.search.trim().toLowerCase();
    return this.players.filter((p) => (!this.onlyOnline || p.online) && (!q || (p.name ?? '').toLowerCase().includes(q)));
  }

  spawn(p: Candidate): void {
    this.busyId = p.id;
    this.msg = null;
    this.http.post<Boss>('/api/admin/bosses/spawn', { playerId: p.id }).subscribe({
      next: (b) => {
        this.busyId = null;
        this.msg = `Riss bei ${b.place} geöffnet (nahe ${p.name}). Spieler im Umkreis von 3 km sehen ihn auf der Karte, beitreten geht im Umkreis von 250 m.`;
        this.loadBosses();
      },
      error: (e) => { this.busyId = null; this.msg = e?.error?.message ?? e?.error ?? 'Riss konnte nicht geöffnet werden.'; this.cd.markForCheck(); },
    });
  }

  /** Checkpoint beim Spieler für 30 Minuten – mit boss = true gleich mit Riss. */
  checkpoint(p: Candidate, boss: boolean): void {
    this.busyId = p.id;
    this.msg = null;
    this.http.post<Checkpoint>('/api/admin/bosses/checkpoints', { playerId: p.id, boss }).subscribe({
      next: () => {
        this.busyId = null;
        this.msg = boss
          ? `Checkpoint und Riss bei ${p.name} – 30 Minuten. Alle sehen „Riss-Punkt“ (ohne Namen, Position auf ~50 m gerundet).`
          : `Checkpoint bei ${p.name} – 30 Minuten. „Riss hier öffnen“ setzt den Boss jetzt genau dorthin.`;
        this.loadBosses();
      },
      error: (e) => { this.busyId = null; this.msg = e?.error?.message ?? e?.error ?? 'Checkpoint konnte nicht angelegt werden.'; this.cd.markForCheck(); },
    });
  }

  removeCheckpoint(c: Checkpoint): void {
    this.http.delete(`/api/admin/bosses/checkpoints/${c.id}`).subscribe(() => { this.msg = 'Checkpoint entfernt.'; this.loadBosses(); });
  }

  pointLink(c: { latitude: number; longitude: number }): string { return `https://www.openstreetmap.org/?mlat=${c.latitude}&mlon=${c.longitude}#map=17/${c.latitude}/${c.longitude}`; }

  close(b: Boss): void {
    this.http.delete(`/api/admin/bosses/${b.id}`).subscribe(() => { this.msg = `Riss bei ${b.place} geschlossen.`; this.loadBosses(); });
  }

  phase(p: string): string { return PHASES[p] ?? p; }

  minutesLeft(iso: string | null): number { return iso ? Math.max(0, Math.round((new Date(iso).getTime() - Date.now()) / 60000)) : 0; }

  hpPercent(b: Boss): number { return Math.round((100 * b.hp) / Math.max(1, b.maxHp)); }

  mapLink(b: Boss): string { return `https://www.openstreetmap.org/?mlat=${b.latitude}&mlon=${b.longitude}#map=17/${b.latitude}/${b.longitude}`; }
}
