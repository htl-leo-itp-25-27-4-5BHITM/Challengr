import { ChangeDetectorRef, Component } from '@angular/core';
import { HttpClient } from '@angular/common/http';

interface FeedbackItem {
  id: string;
  kind: 'SCREENSHOT' | 'CRASH';
  createdAt: string | null;
  comment: string | null;
  tester: string | null;
  testerEmail: string | null;
  device: string | null;
  osVersion: string | null;
  appVersion: string | null;
  screenshots: string[];
  done: boolean;
  doneAt: string | null;
  doneBy: string | null;
}

interface FeedbackFeed {
  configured: boolean;
  items: FeedbackItem[];
  error: string | null;
}

type Filter = 'open' | 'done' | 'all';

/** TestFlight-Feedback (Screenshots mit Text, Abstürze) aus App Store Connect – zum Abhaken. */
@Component({
  selector: 'app-feedback',
  standalone: false,
  templateUrl: './feedback.html',
  styleUrl: './feedback.css',
})
export class Feedback {
  feed: FeedbackFeed | null = null;
  loading = true;
  error: string | null = null;
  filter: Filter = 'open';
  busyId: string | null = null;
  crashLogs: Record<string, string> = {};
  enlarged: string | null = null;

  constructor(private readonly http: HttpClient, private readonly cd: ChangeDetectorRef) {
    this.load(false);
  }

  load(refresh: boolean): void {
    this.loading = true;
    this.error = null;
    this.http.get<FeedbackFeed>(`/api/admin/feedback${refresh ? '?refresh=true' : ''}`).subscribe({
      next: (f) => {
        this.feed = f;
        this.loading = false;
        this.cd.detectChanges();
      },
      error: (err) => {
        this.loading = false;
        this.error = err?.status === 403 ? 'Dieses Konto hat keine Admin-Rolle.' : 'Feedback konnte nicht geladen werden.';
        this.cd.detectChanges();
      },
    });
  }

  get items(): FeedbackItem[] {
    const all = this.feed?.items ?? [];
    if (this.filter === 'open') return all.filter((i) => !i.done);
    if (this.filter === 'done') return all.filter((i) => i.done);
    return all;
  }

  count(filter: Filter): number {
    const all = this.feed?.items ?? [];
    return filter === 'all' ? all.length : all.filter((i) => (filter === 'done') === i.done).length;
  }

  toggleDone(item: FeedbackItem): void {
    this.busyId = item.id;
    const done = !item.done;
    this.http.put(`/api/admin/feedback/${encodeURIComponent(item.id)}/done`, { done }).subscribe({
      next: () => {
        item.done = done;
        item.doneAt = done ? new Date().toISOString() : null;
        this.busyId = null;
        this.cd.detectChanges();
      },
      error: () => {
        this.busyId = null;
        this.error = 'Speichern hat nicht geklappt – bitte nochmal versuchen.';
        this.cd.detectChanges();
      },
    });
  }

  toggleCrashLog(item: FeedbackItem): void {
    if (this.crashLogs[item.id] !== undefined) {
      delete this.crashLogs[item.id];
      return;
    }
    this.crashLogs[item.id] = 'Lade Absturzbericht…';
    this.http.get<{ text: string }>(`/api/admin/feedback/${encodeURIComponent(item.id)}/crash-log`).subscribe({
      next: (r) => {
        this.crashLogs[item.id] = r.text || '(leer)';
        this.cd.detectChanges();
      },
      error: () => {
        this.crashLogs[item.id] = 'Absturzbericht konnte nicht geladen werden.';
        this.cd.detectChanges();
      },
    });
  }
}
