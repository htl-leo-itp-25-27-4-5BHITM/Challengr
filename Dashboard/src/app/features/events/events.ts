import { ChangeDetectorRef, Component, OnInit } from '@angular/core';
import { HttpClient } from '@angular/common/http';

interface Task { id: string; title: string; icon: string; metric: string; target: number; coins: number; }
interface QEvent { id: string; title: string; subtitle: string; start: string; end: string; rewardCharacter: string | null; rewardCoins: number; tasks: Task[]; }
interface EventRow { event: QEvent; state: string; claimed: number; }
interface Meta { metrics: { id: string; label: string }[]; rewardCharacters: { id: string; name: string }[]; }
interface Progress { eventId: string; participants: number; completed: number; claimed: number; tasks: { id: string; title: string; target: number; done: number }[]; computedAt: string; }
interface TaskForm { title: string; metric: string; target: number; }

/** Events (z. B. Halloween): anlegen, bearbeiten, Fortschritt der Spieler. */
@Component({
  selector: 'app-events',
  standalone: false,
  templateUrl: './events.html',
  styleUrls: ['../admin-tools.css'],
})
export class Events implements OnInit {
  rows: EventRow[] = [];
  meta: Meta = { metrics: [], rewardCharacters: [] };
  progress: Record<string, Progress> = {};
  editing: 'new' | string | null = null;
  form = this.empty();
  msg: string | null = null;
  error: string | null = null;
  busy = false;

  constructor(private http: HttpClient, private cd: ChangeDetectorRef) {}

  ngOnInit(): void {
    this.http.get<Meta>('/api/admin/events/meta').subscribe({ next: (m) => { this.meta = m; this.cd.markForCheck(); }, error: () => {} });
    this.load();
  }

  load(): void {
    this.http.get<EventRow[]>('/api/admin/events').subscribe({
      next: (r) => {
        this.rows = r;
        this.error = null;
        r.filter((x) => x.state !== 'geplant').forEach((x) => this.loadProgress(x.event.id));
        this.cd.markForCheck();
      },
      error: () => { this.error = 'Events konnten nicht geladen werden.'; this.cd.markForCheck(); },
    });
  }

  loadProgress(id: string, fresh = false): void {
    this.http.get<Progress>(`/api/admin/events/${id}/progress${fresh ? '?fresh=true' : ''}`).subscribe({
      next: (p) => { this.progress[id] = p; this.cd.markForCheck(); }, error: () => {},
    });
  }

  empty() {
    const today = new Date().toISOString().slice(0, 10);
    return { id: '', title: '', subtitle: '', start: today, end: today, rewardCharacter: '' as string, rewardCoins: 100,
             tasks: [{ title: '', metric: 'BATTLES', target: 5 }] as TaskForm[] };
  }

  newEvent(): void { this.editing = 'new'; this.form = this.empty(); this.msg = null; }

  edit(e: QEvent): void {
    this.editing = e.id;
    this.form = { id: e.id, title: e.title, subtitle: e.subtitle ?? '', start: e.start, end: e.end,
                  rewardCharacter: e.rewardCharacter ?? '', rewardCoins: e.rewardCoins,
                  tasks: e.tasks.map((t) => ({ title: t.title, metric: t.metric, target: t.target })) };
    this.msg = null;
  }

  addTask(): void { if (this.form.tasks.length < 10) this.form.tasks.push({ title: '', metric: 'QUIZ_SHOWS', target: 1 }); }
  removeTask(i: number): void { this.form.tasks.splice(i, 1); }

  save(): void {
    if (this.busy) return;
    this.busy = true;
    const body = { ...this.form, rewardCharacter: this.form.rewardCharacter || null };
    const req = this.editing === 'new' ? this.http.post('/api/admin/events', body) : this.http.put(`/api/admin/events/${this.editing}`, body);
    req.subscribe({
      next: () => { this.busy = false; this.editing = null; this.msg = 'Gespeichert – die App zeigt es beim nächsten Öffnen der Aufgaben.'; this.load(); },
      error: (e) => { this.busy = false; this.msg = e?.error?.message ?? e?.error ?? 'Speichern fehlgeschlagen.'; this.cd.markForCheck(); },
    });
  }

  remove(r: EventRow): void {
    this.http.delete(`/api/admin/events/${r.event.id}`).subscribe({
      next: () => { this.msg = 'Gelöscht.'; this.load(); },
      error: (e) => { this.msg = e?.error?.message ?? e?.error ?? 'Löschen fehlgeschlagen.'; this.cd.markForCheck(); },
    });
  }

  metricLabel(id: string): string { return this.meta.metrics.find((m) => m.id === id)?.label ?? id; }
  charName(id: string | null): string { return id ? this.meta.rewardCharacters.find((c) => c.id === id)?.name ?? id : '–'; }
  pct(done: number, total: number): number { return total ? Math.round((done / total) * 100) : 0; }
}
