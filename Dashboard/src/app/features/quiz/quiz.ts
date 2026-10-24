import { ChangeDetectorRef, Component, OnInit } from '@angular/core';
import { HttpClient } from '@angular/common/http';

interface Question {
  id: number; text: string; choices: string[]; correctIndex: number; active: boolean; edited: boolean;
  answers: number; correct: number; wrong: number; unanswered: number; correctRate: number | null; hard: boolean; openReports: number;
}
interface QuizReport { id: number; questionId: number; questionText: string; reason: string; comment: string | null; status: string; createdAt: string; playerName: string | null; }

const REASONS: Record<string, string> = { FALSCHE_ANTWORT: 'Antwort falsch', UNKLAR: 'Frage unklar', TIPPFEHLER: 'Tippfehler', SONSTIGES: 'Sonstiges' };

/** Quizfragen: suchen, anlegen, bearbeiten, deaktivieren; gemeldete und „fast alle falsch“-Fragen zuerst. */
@Component({
  selector: 'app-quiz',
  standalone: false,
  templateUrl: './quiz.html',
  styleUrls: ['../admin-tools.css'],
})
export class Quiz implements OnInit {
  questions: Question[] = [];
  reports: QuizReport[] = [];
  filter: 'all' | 'reported' | 'hard' | 'inactive' = 'reported';
  search = '';
  error: string | null = null;
  /** Bearbeiten: null = nichts offen, id 0 = neue Frage */
  editId: number | null = null;
  form = { text: '', choices: ['', '', '', ''], correctIndex: 0 };
  msg: string | null = null;
  busy = false;
  readonly letters = ['A', 'B', 'C', 'D'];

  constructor(private http: HttpClient, private cd: ChangeDetectorRef) {}

  ngOnInit(): void { this.load(); }

  load(): void {
    const q = encodeURIComponent(this.search.trim());
    this.http.get<Question[]>(`/api/admin/quiz/questions?filter=${this.filter}&q=${q}`).subscribe({
      next: (r) => { this.questions = r; this.error = null; this.cd.markForCheck(); },
      error: () => { this.error = 'Fragen konnten nicht geladen werden.'; this.cd.markForCheck(); },
    });
    this.http.get<QuizReport[]>('/api/admin/quiz/reports').subscribe({ next: (r) => { this.reports = r; this.cd.markForCheck(); }, error: () => {} });
  }

  setFilter(f: Quiz['filter']): void { this.filter = f; this.load(); }

  reportsFor(id: number): QuizReport[] { return this.reports.filter((r) => r.questionId === id); }
  reasonText(r: string): string { return REASONS[r] ?? r; }
  rate(q: Question): string { return q.correctRate == null ? '–' : Math.round(q.correctRate * 100) + ' %'; }

  newQuestion(): void {
    this.editId = 0;
    this.form = { text: '', choices: ['', '', '', ''], correctIndex: 0 };
    this.msg = null;
  }

  edit(q: Question): void {
    this.editId = q.id;
    this.form = { text: q.text, choices: [...q.choices], correctIndex: q.correctIndex };
    this.msg = null;
  }

  cancel(): void { this.editId = null; this.msg = null; }

  save(): void {
    if (this.busy) return;
    this.busy = true;
    const req = this.editId ? this.http.put<Question>(`/api/admin/quiz/questions/${this.editId}`, this.form)
                            : this.http.post<Question>('/api/admin/quiz/questions', this.form);
    req.subscribe({
      next: () => { this.busy = false; this.editId = null; this.msg = 'Gespeichert – gilt ab der nächsten Quiz-Show.'; this.load(); },
      error: (e) => { this.busy = false; this.msg = e?.error?.message ?? e?.error ?? 'Speichern fehlgeschlagen.'; this.cd.markForCheck(); },
    });
  }

  toggleActive(q: Question): void {
    this.http.put<Question>(`/api/admin/quiz/questions/${q.id}/active`, { active: !q.active }).subscribe(() => this.load());
  }

  resolveReports(q: Question): void {
    this.http.post(`/api/admin/quiz/questions/${q.id}/reports/resolve`, {}).subscribe(() => this.load());
  }
}
