import { Component, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { toSignal } from '@angular/core/rxjs-interop';
import { map } from 'rxjs/operators';

@Component({
  selector: 'app-challenges',
  standalone: false,
  templateUrl: './challenges.html',
  styleUrls: ['./challenges.css'],
})
export class Challenges {
  private http = inject(HttpClient);

  challenges = toSignal(this.http.get<any[]>('/api/challenges'));

  categories = toSignal(
    this.http.get<any[]>('/api/challenges').pipe(
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

  selectCategory(cat: any) {
    this.selectedCategory = cat.name;
  }

  getSelected() {
    return this.categories()?.find((c) => c.name === this.selectedCategory)?.items || [];
  }
}
