import { Component, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { toSignal } from '@angular/core/rxjs-interop';
import { map } from 'rxjs/operators';
import { BehaviorSubject, switchMap } from 'rxjs';

@Component({
  selector: 'app-challenges',
  standalone: false,
  templateUrl: './challenges.html',
  styleUrls: ['./challenges.css'],
})
export class Challenges {
  private http = inject(HttpClient);

  private refresh$ = new BehaviorSubject<void>(undefined);

  challenges = toSignal(
    this.refresh$.pipe(switchMap(() => this.http.get<any[]>('/api/challenges'))),
  );

  categories = toSignal(
    this.refresh$.pipe(
      switchMap(() => this.http.get<any[]>('/api/challenges')),
      map((data) => {
        const grouped: Record<string, any[]> = {};

        for (const c of data) {
          if (!grouped[c.category]) grouped[c.category] = [];
          grouped[c.category].push(c);
        }

        return Object.entries(grouped).map(([name, items]) => ({
          name,
          items,
          count: items.length,
        }));
      }),
    ),
  );

  selectedCategory: string | null = null;

  // Create form model
  createText = '';
  createCategory = '';
  createChoices: string[] = ['', '', '', ''];
  createCorrectIndex: number | null = 0;
  createError: string | null = null;
  isCreating = false;

  selectCategory(cat: any) {
    this.selectedCategory = cat.name;
    // Preselect category in create form for convenience.
    this.createCategory = cat.name;
  }

  getSelected() {
    return this.categories()?.find((c) => c.name === this.selectedCategory)?.items || [];
  }

  get isWissenSelected(): boolean {
    return (this.createCategory || '').toLowerCase() === 'wissen';
  }

  async createChallenge() {
    this.createError = null;
    if (!this.createText.trim()) {
      this.createError = 'Text ist erforderlich.';
      return;
    }
    if (!this.createCategory.trim()) {
      this.createError = 'Kategorie ist erforderlich.';
      return;
    }

    const payload: any = {
      text: this.createText.trim(),
      category: this.createCategory.trim(),
    };

    if (this.isWissenSelected) {
      if (this.createChoices.some((c) => !c.trim())) {
        this.createError = 'Bitte alle 4 Antworten ausfüllen.';
        return;
      }
      if (
        this.createCorrectIndex == null ||
        this.createCorrectIndex < 0 ||
        this.createCorrectIndex > 3
      ) {
        this.createError = 'CorrectIndex muss 0-3 sein.';
        return;
      }
      payload.choices = this.createChoices.map((c) => c.trim());
      payload.correctIndex = this.createCorrectIndex;
    }

    this.isCreating = true;
    try {
      await this.http.post('/api/challenges', payload).toPromise();
      this.createText = '';
      this.createChoices = ['', '', '', ''];
      this.createCorrectIndex = 0;
      this.refresh$.next();
    } catch (e: any) {
      this.createError = e?.error?.message ?? e?.message ?? 'Fehler beim Erstellen.';
    } finally {
      this.isCreating = false;
    }
  }
  showModal = false;

  openModal() {
    this.showModal = true;
  }

  closeModal() {
    this.showModal = false;
  }
}
