import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';

export interface StatsTotals {
  players: number;
  activeToday: number;
  active7d: number;
  newPlayers7d: number;
  returning7d: number;
  battlesToday: number;
  battlesTotal: number;
  checkinsToday: number;
  openReports: number;
  activeBans: number;
}

export interface DayPoint {
  day: string; // yyyy-MM-dd
  activePlayers: number;
  newPlayers: number;
  quiz: number;
  realLife: number;
  friendly: number;
  checkins: number;
}

export interface NamedCount {
  name: string;
  count: number;
}

export interface LeaderRow {
  name: string;
  rank: string;
  trophies: number;
  battles: number;
  wins: number;
  lastSeen: string | null;
}

export interface AdminStats {
  generatedAt: string;
  days: number;
  totals: StatsTotals;
  daily: DayPoint[];
  battlesByHour: number[];
  modes: NamedCount[];
  outcomes: NamedCount[];
  ranks: NamedCount[];
  characters: NamedCount[];
  topChallenges: NamedCount[];
  leaderboard: LeaderRow[];
}

/** Echte Spieldaten fürs Dashboard (`GET /api/admin/stats`). Keine Beispieldaten – bei Fehlern sieht man den Fehler. */
@Injectable({ providedIn: 'root' })
export class AdminStatsApi {
  constructor(private readonly http: HttpClient) {}

  get(days: number): Observable<AdminStats> {
    return this.http.get<AdminStats>(`/api/admin/stats?days=${days}`);
  }
}
