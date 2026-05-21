import { Component, computed, effect, signal, ViewChild, ElementRef } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { toSignal } from '@angular/core/rxjs-interop';
import { catchError, of, type Observable } from 'rxjs';
import { DomSanitizer, SafeHtml } from '@angular/platform-browser';

type ErdResponse = {
  catalog: string | null;
  schema: string | null;
  tables: Array<{
    name: string;
    columns: Array<{ name: string; type: string; nullable: boolean }>;
    primaryKey: string[];
  }>;
  relations: Array<{
    fromTable: string;
    fromColumns: string[];
    toTable: string;
    toColumns: string[];
    name: string;
  }>;
};

type TableDataResponse = {
  table: string;
  columns: string[];
  rows: Array<Record<string, unknown>>;
};

@Component({
  selector: 'app-erd',
  standalone: false,
  templateUrl: './erd.html',
  styleUrl: './erd.css',
})
export class Erd {
  private readonly erd$: Observable<ErdResponse | null>;
  readonly erd;

  // Rendered SVG output of Mermaid
  readonly renderedSvg = signal<SafeHtml | null>(null);

  @ViewChild('diagramContainer')
  private readonly diagramContainer?: ElementRef<HTMLDivElement>;
  private diagramClickHandler?: (event: Event) => void;

  readonly selectedTable = signal<string | null>(null);
  readonly tableData = signal<TableDataResponse | null>(null);
  readonly tableLoading = signal<boolean>(false);
  readonly tableError = signal<string | null>(null);

  readonly mermaid = computed(() => {
    const erd = this.erd();
    if (!erd) return '';

    // Mermaid class diagram syntax (more "Klassendiagramm" feel)
    // https://mermaid.js.org/syntax/classDiagram.html
  const lines: string[] = ['classDiagram', 'direction LR'];

    for (const table of erd.tables) {
      const className = sanitizeId(table.name);
      lines.push(`class ${className} {`);

      const pk = new Set(table.primaryKey ?? []);
      const cols = (table.columns ?? []).filter((c) => !shouldHideColumn(table.name, c.name));

      // Keep it readable: if there are too many columns, still show a hint.
      const maxCols = 30;
      const shown = cols.slice(0, maxCols);
      for (const col of shown) {
        const flags = [pk.has(col.name) ? 'PK' : '', col.nullable ? '' : 'NN']
          .filter(Boolean)
          .join(' ');
        const type = shortType(col.type);
        lines.push(`  +${sanitizeId(col.name)} : ${sanitizeId(type)}${flags ? ' <<' + flags + '>>' : ''}`);
      }
      if (cols.length > maxCols) {
        lines.push(`  .. +${cols.length - maxCols} weitere Spalten`);
      }

      lines.push('}');
    }

    // Associations: many (FK table) to one (PK table)
    for (const rel of erd.relations) {
      const from = sanitizeId(rel.fromTable);
      const to = sanitizeId(rel.toTable);
      const label = relationLabel(rel);
      const suffix = label ? ` : ${escapeLabel(label)}` : '';
      lines.push(`${from} "*" --> "1" ${to}${suffix}`);
    }

    return lines.join('\n');
  });

  constructor(private readonly http: HttpClient, private readonly sanitizer: DomSanitizer) {
    this.erd$ = this.http.get<ErdResponse>('/api/admin/erd').pipe(
      catchError((err) => {
        console.error('Failed to load ERD', err);
        return of(null);
      })
    );

    this.erd = toSignal(this.erd$, { initialValue: null });

    // Render Mermaid to SVG (client-side). If rendering fails, we still show the raw code.
    effect(async () => {
      const code = this.mermaid();
      if (!code) {
        this.renderedSvg.set(null);
        return;
      }

      // In SSR we don't have window/document.
      if (typeof window === 'undefined') {
        this.renderedSvg.set(null);
        return;
      }

      try {
        // Use ESM build from CDN so we don't need an extra dependency in the Dashboard.
        // TS can't type-check URL imports, so we load via a runtime dynamic import.
        const mermaidModule = (await (new Function(
          "u",
          "return import(u)"
        ) as (u: string) => Promise<any>)(
          'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs'
        )) as any;
        const mermaid = (mermaidModule?.default ?? mermaidModule) as any;

        mermaid.initialize({
          startOnLoad: false,
          // UML-like classic styling
          theme: 'base',
          securityLevel: 'strict',
          themeVariables: {
            background: '#fffbe6',
            primaryColor: '#fffbe6',
            primaryBorderColor: '#3b3b3b',
            primaryTextColor: '#2b2b2b',

            lineColor: '#3b3b3b',
            textColor: '#2b2b2b',

            // classDiagram specifics
            classText: '#2b2b2b',
            classBorder: '#3b3b3b',
            classBackground: '#fff9c4',
          },
        });

        const id = 'erdDiagram';
        const { svg } = await mermaid.render(id, code);
        this.renderedSvg.set(this.sanitizer.bypassSecurityTrustHtml(svg));

        // Attach click handler once SVG is in the DOM
        setTimeout(() => this.bindDiagramClick(), 0);
      } catch (e) {
        console.warn('Mermaid rendering failed; falling back to raw code', e);
        this.renderedSvg.set(null);
      }
    });
  }

  selectTable(tableName: string) {
    if (!tableName) return;
    this.selectedTable.set(tableName);
    this.tableLoading.set(true);
    this.tableError.set(null);

    this.http
      .get<TableDataResponse>(`/api/admin/erd/table/${encodeURIComponent(tableName)}?limit=50`)
      .pipe(
        catchError((err) => {
          console.error('Failed to load table data', err);
          this.tableError.set('Konnte Tabellendaten nicht laden.');
          return of(null);
        })
      )
      .subscribe((data) => {
        this.tableData.set(data);
        this.tableLoading.set(false);
      });
  }

  private bindDiagramClick() {
    const container = this.diagramContainer?.nativeElement;
    if (!container) return;

    if (this.diagramClickHandler) {
      container.removeEventListener('click', this.diagramClickHandler);
    }

    this.diagramClickHandler = (event: Event) => {
      const path = (event as any).composedPath?.() as HTMLElement[] | undefined;
      const target = (event.target as HTMLElement | null) ?? null;

      const node =
        path?.find((el) => el?.classList?.contains('classGroup')) ||
        target?.closest('g.classGroup, g.node, g[class*="node"]');
      if (!node) return;

      const title = node.querySelector('title')?.textContent?.trim();
      const textNodes = Array.from(node.querySelectorAll('text, tspan'));
      const firstText = textNodes.find((t) => t.textContent && t.textContent.trim().length > 0);
      const label = title || (firstText?.textContent?.trim() ?? '');
      if (!label) return;

      const normalized = normalizeTableName(label);
      const table = this.erd()?.tables.find(
        (t) => normalizeTableName(t.name) === normalized
      );
      if (table) {
        this.selectTable(table.name);
      }
    };

    container.addEventListener('click', this.diagramClickHandler);
  }
}

function sanitizeId(id: string): string {
  // Mermaid ids: avoid spaces/dashes
  return (id ?? '').replace(/[^a-zA-Z0-9_]/g, '_');
}

function sanitizeType(type: string): string {
  // Mermaid wants a "type" token; keep it simple
  return sanitizeId(type || 'text');
}

function escapeLabel(label: string): string {
  return (label ?? '').replace(/"/g, "'");
}

function shortType(type: string): string {
  const t = (type ?? '').toLowerCase();
  if (t.includes('int')) return 'int';
  if (t.includes('float') || t.includes('double') || t.includes('numeric') || t.includes('dec')) return 'number';
  if (t.includes('bool')) return 'boolean';
  if (t.includes('timestamp') || t.includes('date') || t.includes('time')) return 'datetime';
  if (t.includes('uuid')) return 'uuid';
  if (t.includes('json')) return 'json';
  if (t.includes('char') || t.includes('text') || t.includes('varchar')) return 'string';
  return type || 'text';
}

function relationLabel(rel: { name: string; fromColumns: string[]; toColumns: string[] }): string {
  // Hide noisy FK names (auto-generated), use column names instead.
  const from = (rel.fromColumns ?? []).join(', ');
  const to = (rel.toColumns ?? []).join(', ');
  if (from || to) {
    return to ? `${from} -> ${to}` : from;
  }
  return '';
}

function normalizeTableName(name: string): string {
  return (name ?? '').trim().toLowerCase();
}

function shouldHideColumn(table: string, column: string): boolean {
  const t = (table ?? '').toLowerCase();
  const c = (column ?? '').toLowerCase();

  // Generic noise columns (tune later)
  const noisy = new Set([
    'password',
    'secret',
    'token',
    'salt',
    'hash',
    'access_token',
    'refresh_token',
    'representation',
    'error',
  ]);
  if (noisy.has(c)) return true;

  // Keycloak-style audit/event blob columns if any slip through
  if (t.includes('event') && (c.includes('representation') || c.includes('resource'))) return true;

  return false;
}
