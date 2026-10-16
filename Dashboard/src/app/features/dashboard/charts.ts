import { AfterViewInit, ChangeDetectorRef, Component, Directive, ElementRef, Input, OnChanges, OnDestroy, inject } from '@angular/core';

/** Eine Datenreihe: Name (Legende/Tooltip), Farbe (CSS-Variable) und ein Wert pro Beschriftung. */
export interface ChartSeries {
  name: string;
  color: string;
  values: number[];
}

/** Runde Achsen-Obergrenze und Schrittweite (1, 2, 5 × 10^n), damit die Hilfslinien glatte Zahlen haben. */
function niceScale(max: number, ticks = 4): { top: number; step: number } {
  if (max <= 0) return { top: ticks, step: 1 };
  const raw = max / ticks;
  const pow = Math.pow(10, Math.floor(Math.log10(raw)));
  const step = [1, 2, 5, 10].map((m) => m * pow).find((s) => s >= raw) ?? 10 * pow;
  const s = Math.max(1, step);
  return { top: s * Math.max(1, Math.ceil(max / s)), step: s };
}

/** Misst die echte Breite des Diagramms, damit SVG-Pixel = Bildschirm-Pixel (nichts wird verzerrt). */
@Directive()
abstract class Measured implements AfterViewInit, OnDestroy, OnChanges {
  private readonly host = inject(ElementRef<HTMLElement>);
  private readonly cd = inject(ChangeDetectorRef);
  private observer?: ResizeObserver;
  W = 600;
  readonly H = 220;

  ngAfterViewInit(): void {
    if (typeof window === 'undefined') return;   // Server-Rendering
    const plot = this.host.nativeElement.querySelector('.plot') as HTMLElement | null;
    if (!plot) return;
    // gleich nach dem Aufbau messen, danach bei jeder Größenänderung
    setTimeout(() => this.resize(plot.getBoundingClientRect().width));
    if (typeof ResizeObserver !== 'undefined') {
      this.observer = new ResizeObserver(([entry]) => this.resize(entry.contentRect.width));
      this.observer.observe(plot);
    }
  }

  private resize(width: number): void {
    const w = Math.round(width);
    if (w > 0 && w !== this.W) {
      this.W = w;
      this.ngOnChanges();
      this.cd.detectChanges();   // die App läuft ohne automatische Änderungserkennung
    }
  }

  ngOnDestroy(): void {
    this.observer?.disconnect();
  }

  abstract ngOnChanges(): void;
}

/** "2026-10-16" → "16.10." */
export function shortDate(iso: string): string {
  const [, m, d] = iso.split('-');
  return `${d}.${m}.`;
}

/**
 * Verlauf über die Zeit (Linien). Fadenkreuz + Tooltip beim Überfahren, Legende ab zwei Reihen,
 * Tabelle für Screenreader.
 */
@Component({
  selector: 'app-trend-chart',
  standalone: false,
  template: `
    <div class="chart" (mouseleave)="hover = null">
      @if (series.length > 1) {
        <div class="legend">
          @for (s of series; track s.name) {
            <span class="legend-item"><i class="swatch line" [style.background]="s.color"></i>{{ s.name }}</span>
          }
        </div>
      }
      <div class="plot-wrap">
        <div class="y-axis">
          @for (t of ticks; track t) {
            <span [style.top.px]="y(t)">{{ t }}</span>
          }
        </div>
        <div class="plot">
          <svg [attr.viewBox]="'0 0 ' + W + ' ' + H" [attr.width]="W" [attr.height]="H" role="img" [attr.aria-label]="label">
            @for (t of ticks; track t) {
              <line class="grid" [attr.x1]="padL" [attr.x2]="W - padR" [attr.y1]="y(t)" [attr.y2]="y(t)" />
            }
            @for (s of series; track s.name) {
              <path [attr.d]="area(s)" [attr.fill]="s.color" opacity="0.10" />
              <path [attr.d]="path(s)" fill="none" [attr.stroke]="s.color" stroke-width="2"
                    stroke-linejoin="round" stroke-linecap="round" />
            }
            @if (hover !== null) {
              <line class="crosshair" [attr.x1]="x(hover)" [attr.x2]="x(hover)" [attr.y1]="padT" [attr.y2]="H - padB" />
              @for (s of series; track s.name) {
                <circle class="dot" [attr.cx]="x(hover)" [attr.cy]="y(s.values[hover])" r="4.5" [attr.fill]="s.color" />
              }
            }
            <rect [attr.x]="0" [attr.y]="0" [attr.width]="W" [attr.height]="H" fill="transparent" (mousemove)="move($event)" />
          </svg>
          <div class="x-labels">
            @for (i of xLabelIdx; track i) {
              <span [style.left.px]="x(i)">{{ fmt(labels[i]) }}</span>
            }
          </div>
          @if (hover !== null) {
            <div class="tooltip" [style.left.px]="x(hover)" [class.flip]="x(hover) > W * 0.6">
              <div class="tt-title">{{ fmt(labels[hover]) }}</div>
              @for (s of series; track s.name) {
                <div class="tt-row"><i class="swatch" [style.background]="s.color"></i>{{ s.name }}<b>{{ s.values[hover] }}</b></div>
              }
            </div>
          }
        </div>
      </div>
      <table class="visually-hidden">
        <caption>{{ label }}</caption>
        <thead><tr><th>Tag</th>@for (s of series; track s.name) {<th>{{ s.name }}</th>}</tr></thead>
        <tbody>
        @for (l of labels; track $index) {
          <tr><td>{{ fmt(l) }}</td>@for (s of series; track s.name) {<td>{{ s.values[$index] }}</td>}</tr>
        }
        </tbody>
      </table>
    </div>
  `,
  styleUrl: './charts.css',
})
export class TrendChart extends Measured {
  @Input() labels: string[] = [];
  @Input() series: ChartSeries[] = [];
  @Input() label = '';
  @Input() dateLabels = true;

  readonly padL = 6;
  readonly padR = 6;
  readonly padT = 10;
  readonly padB = 26;
  ticks: number[] = [];
  top = 1;
  xLabelIdx: number[] = [];
  hover: number | null = null;

  ngOnChanges(): void {
    const max = Math.max(0, ...this.series.flatMap((s) => s.values));
    const { top, step } = niceScale(max);
    this.top = top;
    this.ticks = [];
    for (let t = 0; t <= top; t += step) this.ticks.push(t);
    const n = this.labels.length;
    this.xLabelIdx = n <= 1 ? [0] : [0, Math.round((n - 1) / 3), Math.round(((n - 1) * 2) / 3), n - 1];
  }

  fmt(l: string): string {
    return this.dateLabels ? shortDate(l) : l;
  }

  x(i: number): number {
    const n = Math.max(1, this.labels.length - 1);
    return this.padL + (i / n) * (this.W - this.padL - this.padR);
  }

  y(v: number): number {
    return this.H - this.padB - (v / this.top) * (this.H - this.padT - this.padB);
  }

  path(s: ChartSeries): string {
    return s.values.map((v, i) => `${i ? 'L' : 'M'}${this.x(i)},${this.y(v)}`).join(' ');
  }

  area(s: ChartSeries): string {
    if (!s.values.length) return '';
    return `${this.path(s)} L${this.x(s.values.length - 1)},${this.y(0)} L${this.x(0)},${this.y(0)} Z`;
  }

  move(e: MouseEvent): void {
    const rect = (e.currentTarget as SVGRectElement).getBoundingClientRect();
    const rel = e.clientX - rect.left;
    const n = this.labels.length - 1;
    const i = Math.round(((rel - this.padL) / (this.W - this.padL - this.padR)) * n);
    this.hover = Math.max(0, Math.min(n, i));
  }
}

/**
 * Säulen (optional gestapelt). Tooltip pro Säule, 2 px Abstand zwischen gestapelten Teilen, oben abgerundet.
 */
@Component({
  selector: 'app-bar-chart',
  standalone: false,
  template: `
    <div class="chart" (mouseleave)="hover = null">
      @if (series.length > 1) {
        <div class="legend">
          @for (s of series; track s.name) {
            <span class="legend-item"><i class="swatch" [style.background]="s.color"></i>{{ s.name }}</span>
          }
        </div>
      }
      <div class="plot-wrap">
        <div class="y-axis">
          @for (t of ticks; track t) {
            <span [style.top.px]="y(t)">{{ t }}</span>
          }
        </div>
        <div class="plot">
          <svg [attr.viewBox]="'0 0 ' + W + ' ' + H" [attr.width]="W" [attr.height]="H" role="img" [attr.aria-label]="label">
            @for (t of ticks; track t) {
              <line class="grid" [attr.x1]="0" [attr.x2]="W" [attr.y1]="y(t)" [attr.y2]="y(t)" />
            }
            @for (l of labels; track $index; let i = $index) {
              <g (mouseenter)="hover = i" [class.dim]="hover !== null && hover !== i">
                <rect [attr.x]="slot(i)" [attr.y]="0" [attr.width]="slotW" [attr.height]="H" fill="transparent" />
                @for (seg of segments(i); track seg.color) {
                  <path [attr.d]="seg.d" [attr.fill]="seg.color" />
                }
              </g>
            }
          </svg>
          <div class="x-labels">
            @for (i of xLabelIdx; track i) {
              <span [style.left.px]="slot(i) + slotW / 2">{{ fmt(labels[i]) }}</span>
            }
          </div>
          @if (hover !== null) {
            <div class="tooltip" [style.left.px]="slot(hover) + slotW / 2" [class.flip]="slot(hover) > W * 0.6">
              <div class="tt-title">{{ fmtLong(labels[hover]) }}</div>
              @for (s of series; track s.name) {
                <div class="tt-row"><i class="swatch" [style.background]="s.color"></i>{{ s.name }}<b>{{ s.values[hover] }}</b></div>
              }
              @if (series.length > 1) {
                <div class="tt-row tt-sum">Gesamt<b>{{ total(hover) }}</b></div>
              }
            </div>
          }
        </div>
      </div>
      <table class="visually-hidden">
        <caption>{{ label }}</caption>
        <thead><tr><th></th>@for (s of series; track s.name) {<th>{{ s.name }}</th>}</tr></thead>
        <tbody>
        @for (l of labels; track $index) {
          <tr><td>{{ fmtLong(l) }}</td>@for (s of series; track s.name) {<td>{{ s.values[$index] }}</td>}</tr>
        }
        </tbody>
      </table>
    </div>
  `,
  styleUrl: './charts.css',
})
export class BarChart extends Measured {
  @Input() labels: string[] = [];
  @Input() series: ChartSeries[] = [];
  @Input() label = '';
  /** 'date' = yyyy-MM-dd, 'hour' = 0–23, sonst Text */
  @Input() labelKind: 'date' | 'hour' | 'text' = 'date';

  readonly padT = 10;
  readonly padB = 26;
  ticks: number[] = [];
  top = 1;
  slotW = 10;
  xLabelIdx: number[] = [];
  hover: number | null = null;

  ngOnChanges(): void {
    const max = Math.max(0, ...this.labels.map((_, i) => this.total(i)));
    const { top, step } = niceScale(max);
    this.top = top;
    this.ticks = [];
    for (let t = 0; t <= top; t += step) this.ticks.push(t);
    this.slotW = this.W / Math.max(1, this.labels.length);
    const n = this.labels.length;
    const every = this.labelKind === 'hour' ? 3 : Math.max(1, Math.ceil(n / 6));
    this.xLabelIdx = [];
    for (let i = 0; i < n; i += every) this.xLabelIdx.push(i);
  }

  total(i: number): number {
    return this.series.reduce((sum, s) => sum + (s.values[i] ?? 0), 0);
  }

  slot(i: number): number {
    return i * this.slotW;
  }

  y(v: number): number {
    return this.H - this.padB - (v / this.top) * (this.H - this.padT - this.padB);
  }

  /** Gestapelte Teile einer Säule; nur das oberste ist oben abgerundet, 2 px Abstand dazwischen. */
  segments(i: number): { d: string; color: string }[] {
    const barW = Math.max(3, Math.min(this.slotW * 0.62, 26));
    const x = this.slot(i) + (this.slotW - barW) / 2;
    const parts = this.series.filter((s) => (s.values[i] ?? 0) > 0);
    let base = 0;
    return parts.map((s, k) => {
      const v = s.values[i];
      const yBottom = this.y(base) - (k > 0 ? 2 : 0);
      const yTop = this.y(base + v);
      base += v;
      const h = Math.max(1, yBottom - yTop);
      const t = yBottom - h;
      const r = k === parts.length - 1 ? Math.min(4, barW / 2, h) : 0;
      const d = r > 0
        ? `M${x},${yBottom} V${t + r} Q${x},${t} ${x + r},${t} H${x + barW - r} Q${x + barW},${t} ${x + barW},${t + r} V${yBottom} Z`
        : `M${x},${yBottom} V${t} H${x + barW} V${yBottom} Z`;
      return { d, color: s.color };
    });
  }

  fmt(l: string): string {
    if (this.labelKind === 'date') return shortDate(l);
    if (this.labelKind === 'hour') return `${l} Uhr`;
    return l;
  }

  fmtLong(l: string): string {
    if (this.labelKind === 'date') return shortDate(l);
    if (this.labelKind === 'hour') return `${l}:00–${l}:59 Uhr`;
    return l;
  }
}

/** Liste mit waagrechten Balken – Name, Balken, Zahl (Werte direkt beschriftet, kein Tooltip nötig). */
@Component({
  selector: 'app-hbar-list',
  standalone: false,
  template: `
    @if (!items.length || max === 0) {
      <div class="muted hbar-empty">Noch keine Daten</div>
    } @else {
      <ul class="hbars" [attr.aria-label]="label">
        @for (it of items; track it.name) {
          <li [title]="it.name + ': ' + it.count">
            <span class="hbar-name">{{ it.name }}</span>
            <span class="hbar-track"><span class="hbar-fill" [style.width.%]="it.count / max * 100"
                  [style.background]="color"></span></span>
            <span class="hbar-value">{{ it.count }}</span>
          </li>
        }
      </ul>
    }
  `,
  styleUrl: './charts.css',
})
export class HBarList implements OnChanges {
  @Input() items: { name: string; count: number }[] = [];
  @Input() color = 'var(--series-single)';
  @Input() label = '';
  max = 0;

  ngOnChanges(): void {
    this.max = Math.max(0, ...this.items.map((i) => i.count));
  }
}
