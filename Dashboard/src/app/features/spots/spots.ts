import { AfterViewInit, ChangeDetectorRef, Component, ElementRef, Inject, OnDestroy, OnInit, PLATFORM_ID, ViewChild } from '@angular/core';
import { isPlatformBrowser } from '@angular/common';
import { HttpClient } from '@angular/common/http';

interface Popular { id: string; name: string; kind: string; latitude: number | null; longitude: number | null; checkins: number; players: number; }
interface HeatCell { latitude: number; longitude: number; players: number; }
interface Heatmap { days: number; minPlayersPerCell: number; playersWithPosition: number; cells: HeatCell[]; spots: Popular[]; }
interface LandmarkRow { id: string; name: string; category: string | null; latitude: number; longitude: number; hidden: boolean; checkins30d: number; }
interface CustomSpot { id: string; name: string; latitude: number; longitude: number; radiusMeters: number; points: number; bonus: number; active: boolean; checkins30d: number; }

const SCHOOL: [number, number] = [14.25138, 48.26832];

/** Check-in-Orte: Heatmap, beliebteste Orte, eigene Orte, OpenStreetMap-Orte ausblenden. */
@Component({
  selector: 'app-spots',
  standalone: false,
  templateUrl: './spots.html',
  styleUrls: ['../admin-tools.css', './spots.css'],
})
export class Spots implements OnInit, AfterViewInit, OnDestroy {
  @ViewChild('map') mapEl?: ElementRef<HTMLDivElement>;
  heat: Heatmap | null = null;
  landmarks: LandmarkRow[] = [];
  custom: CustomSpot[] = [];
  search = '';
  showHidden = false;
  spotForm = { name: '', coords: '', radiusMeters: 60, points: 10, bonus: 15 };
  editSpotId: string | null = null;
  msg: string | null = null;
  error: string | null = null;
  private map: any;
  private browser: boolean;

  constructor(private http: HttpClient, private cd: ChangeDetectorRef, @Inject(PLATFORM_ID) platformId: object) {
    this.browser = isPlatformBrowser(platformId);
  }

  ngOnInit(): void {
    this.loadLandmarks();
    this.loadCustom();
  }

  async ngAfterViewInit(): Promise<void> {
    if (!this.browser || !this.mapEl) return;
    const maplibregl = (await import('maplibre-gl')).default;
    this.map = new maplibregl.Map({
      container: this.mapEl.nativeElement,
      style: 'https://tiles.openfreemap.org/styles/dark',
      center: SCHOOL, zoom: 12, attributionControl: { compact: true },
    });
    this.map.on('load', () => this.loadHeat());
  }

  ngOnDestroy(): void { this.map?.remove(); }

  loadHeat(): void {
    this.http.get<Heatmap>('/api/admin/spots/heatmap').subscribe({
      next: (h) => { this.heat = h; this.drawHeat(h); this.cd.markForCheck(); },
      error: () => { this.error = 'Auswertung konnte nicht geladen werden.'; this.cd.markForCheck(); },
    });
  }

  private drawHeat(h: Heatmap): void {
    if (!this.map) return;
    const cells = { type: 'FeatureCollection', features: h.cells.map((c) => ({ type: 'Feature', properties: { players: c.players },
      geometry: { type: 'Point', coordinates: [c.longitude, c.latitude] } })) };
    const spots = { type: 'FeatureCollection', features: h.spots.filter((s) => s.latitude != null).map((s) => ({ type: 'Feature',
      properties: { checkins: s.checkins, name: s.name }, geometry: { type: 'Point', coordinates: [s.longitude, s.latitude] } })) };
    for (const id of ['heat', 'spots-circle', 'spots-label']) if (this.map.getLayer(id)) this.map.removeLayer(id);
    for (const id of ['cells', 'spots']) if (this.map.getSource(id)) this.map.removeSource(id);
    this.map.addSource('cells', { type: 'geojson', data: cells });
    this.map.addSource('spots', { type: 'geojson', data: spots });
    this.map.addLayer({ id: 'heat', type: 'heatmap', source: 'cells', paint: {
      'heatmap-weight': ['interpolate', ['linear'], ['get', 'players'], 3, 0.3, 30, 1],
      'heatmap-radius': ['interpolate', ['linear'], ['zoom'], 10, 18, 15, 45],
      'heatmap-intensity': 1.2,
      'heatmap-color': ['interpolate', ['linear'], ['heatmap-density'], 0, 'rgba(0,0,0,0)', 0.3, '#7a1f2e', 0.6, '#d23a4f', 1, '#fdd006'],
    } });
    this.map.addLayer({ id: 'spots-circle', type: 'circle', source: 'spots', paint: {
      'circle-radius': ['interpolate', ['linear'], ['get', 'checkins'], 1, 5, 50, 16],
      'circle-color': '#e9b949', 'circle-stroke-color': '#120c0f', 'circle-stroke-width': 2,
    } });
    this.map.addLayer({ id: 'spots-label', type: 'symbol', source: 'spots', layout: {
      'text-field': ['get', 'name'], 'text-size': 12, 'text-offset': [0, 1.3], 'text-anchor': 'top', 'text-font': ['Noto Sans Regular'],
    }, paint: { 'text-color': '#eee7ea', 'text-halo-color': '#120c0f', 'text-halo-width': 1.5 } });
  }

  focus(lat: number | null, lon: number | null): void {
    if (lat != null && lon != null) this.map?.flyTo({ center: [lon, lat], zoom: 16 });
  }

  loadLandmarks(): void {
    const q = encodeURIComponent(this.search.trim());
    this.http.get<LandmarkRow[]>(`/api/admin/spots/landmarks?q=${q}&hidden=${this.showHidden}`).subscribe({
      next: (r) => { this.landmarks = r; this.cd.markForCheck(); }, error: () => {},
    });
  }

  toggleHidden(l: LandmarkRow): void {
    const req = l.hidden ? this.http.delete(`/api/admin/spots/landmarks/${l.id}/hide`)
                         : this.http.post(`/api/admin/spots/landmarks/${l.id}/hide`, { reason: 'im Dashboard ausgeblendet' });
    req.subscribe(() => { this.loadLandmarks(); this.loadHeat(); });
  }

  loadCustom(): void {
    this.http.get<CustomSpot[]>('/api/admin/spots/custom').subscribe({ next: (r) => { this.custom = r; this.cd.markForCheck(); }, error: () => {} });
  }

  /** "48.2683, 14.2514" (aus Google Maps kopiert) → Zahlen */
  private parseCoords(): [number, number] | null {
    const m = this.spotForm.coords.replace(/[()]/g, '').split(/[,;\s]+/).filter(Boolean).map(Number);
    return m.length === 2 && m.every(Number.isFinite) ? [m[0], m[1]] : null;
  }

  editSpot(s: CustomSpot): void {
    this.editSpotId = s.id;
    this.spotForm = { name: s.name, coords: `${s.latitude}, ${s.longitude}`, radiusMeters: s.radiusMeters, points: s.points, bonus: s.bonus };
  }

  saveSpot(): void {
    const c = this.parseCoords();
    if (!c) { this.msg = 'Koordinaten bitte als „48.2683, 14.2514“ (in Google Maps Rechtsklick → Koordinaten kopieren).'; return; }
    const body = { name: this.spotForm.name, latitude: c[0], longitude: c[1], radiusMeters: this.spotForm.radiusMeters,
                   points: this.spotForm.points, bonus: this.spotForm.bonus };
    const req = this.editSpotId ? this.http.put(`/api/admin/spots/custom/${this.editSpotId}`, body) : this.http.post('/api/admin/spots/custom', body);
    req.subscribe({
      next: () => { this.msg = 'Gespeichert – sofort in der App sichtbar.'; this.editSpotId = null;
                    this.spotForm = { name: '', coords: '', radiusMeters: 60, points: 10, bonus: 15 }; this.loadCustom(); },
      error: (e) => { this.msg = e?.error?.message ?? e?.error ?? 'Speichern fehlgeschlagen.'; this.cd.markForCheck(); },
    });
  }

  deactivate(s: CustomSpot): void { this.http.delete(`/api/admin/spots/custom/${s.id}`).subscribe(() => this.loadCustom()); }
}
