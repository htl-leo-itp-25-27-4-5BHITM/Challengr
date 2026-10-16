import { ChangeDetectorRef, Component, OnInit } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { forkJoin } from 'rxjs';

interface Rank { name: string; min: number; max: number; color: string; }

interface PlayerRow {
  id: string;
  name: string;
  trophies: number;
  highestTrophies: number;
  points: number;
  character: string;
  rank: string;
  rankColor: string;
  lastSeenAt: string | null;
  createdAt: string | null;
  invisible: boolean;
  banUntil: string | null;
  banReason: string | null;
  active: boolean;
}

/** Figuren-Ids → Namen (wie GameCharacter in der App) */
const CHARACTERS: Record<string, string> = {
  'junge': 'Junge', 'maedchen': 'Mädchen', 'sir-brecht': 'Sir Brecht', 'ragnar': 'Ragnar', 'hayato': 'Hayato',
  'kage': 'Kage', 'kai': 'Kai', 'merlo': 'Merlo', 'lyra': 'Lyra', 'kaeptn-rex': "Käpt'n Rex",
};

/** Rangfarben wie in der App (TrophyRank.uiColor), für dunklen Grund leicht aufgehellt */
const RANK_COLORS: Record<string, string> = {
  gray: '#9a8f95', red: '#e0384f', green: '#2fbf71', yellow: '#fdd006', orange: '#f08a24', purple: '#a67be8',
};

const ACTIVE_DAYS = 7;

/** Spieler suchen, ansehen und sperren. */
@Component({
  selector: 'app-users',
  templateUrl: './users.html',
  standalone: false,
  styleUrls: ['./users.css'],
})
export class Users implements OnInit {
  users: PlayerRow[] = [];
  filteredUsers: PlayerRow[] = [];
  selectedUser: PlayerRow | null = null;

  totalUsers = 0;
  activeUsers = 0;
  bannedUsers = 0;

  search = '';
  orderBy: 'trophies' | 'name' | 'lastSeen' = 'trophies';
  error: string | null = null;

  banHours = 24;
  banReason = '';
  banBusy = false;
  banMessage: string | null = null;

  constructor(private http: HttpClient, private cd: ChangeDetectorRef) {}

  ngOnInit(): void {
    forkJoin({
      players: this.http.get<any[]>('/api/players'),
      ranks: this.http.get<Rank[]>('/api/ranks'),
    }).subscribe({
      next: ({ players, ranks }) => {
        const sorted = [...ranks].sort((a, b) => a.min - b.min);
        const weekAgo = Date.now() - ACTIVE_DAYS * 86_400_000;
        this.users = players
          .filter((p) => p.id !== 'deleted-player')
          .map((p) => {
            const rank = [...sorted].reverse().find((r) => (p.trophies ?? 0) >= r.min) ?? sorted[0];
            return {
              id: p.id,
              name: p.name ?? '(ohne Namen)',
              trophies: p.trophies ?? 0,
              highestTrophies: p.highestTrophies ?? p.trophies ?? 0,
              points: p.points ?? 0,
              character: CHARACTERS[p.character ?? 'junge'] ?? p.character,
              rank: rank?.name ?? '–',
              rankColor: RANK_COLORS[rank?.color ?? 'gray'] ?? '#9a8f95',
              lastSeenAt: p.lastSeenAt ?? null,
              createdAt: p.createdAt ?? null,
              invisible: !!p.invisible,
              banUntil: p.banUntil ?? null,
              banReason: p.banReason ?? null,
              active: !!p.lastSeenAt && new Date(p.lastSeenAt).getTime() > weekAgo,
            };
          });
        this.calculateStats();
        this.applyFilters();
        this.cd.detectChanges();
      },
      error: (err) => {
        this.error = err?.status === 403 ? 'Dieses Konto hat keine Admin-Rolle.' : 'Spieler konnten nicht geladen werden.';
        this.cd.detectChanges();
      },
    });
  }

  isBanned(user: PlayerRow | null): boolean {
    if (!user?.banUntil) return false;
    const t = new Date(user.banUntil).getTime();
    return Number.isFinite(t) && t > Date.now();
  }

  lastSeen(iso: string | null): string {
    if (!iso) return 'nie';
    const mins = Math.round((Date.now() - new Date(iso).getTime()) / 60000);
    if (mins < 5) return 'gerade aktiv';
    if (mins < 60) return `vor ${mins} min`;
    const h = Math.round(mins / 60);
    if (h < 24) return `vor ${h} h`;
    const d = Math.round(h / 24);
    return d === 1 ? 'vor 1 Tag' : `vor ${d} Tagen`;
  }

  selectUser(user: PlayerRow): void {
    this.selectedUser = user;
    this.banMessage = null;
  }

  banSelected(): void {
    const user = this.selectedUser;
    const hours = Number(this.banHours);
    if (!user || this.banBusy || !Number.isFinite(hours) || hours <= 0) return;
    this.banBusy = true;
    this.http
      .post<any>(`/api/admin/players/${encodeURIComponent(user.id)}/ban`, {
        durationSeconds: Math.round(hours * 3600),
        reason: this.banReason || null,
      })
      .subscribe({
        next: (res) => this.afterBan(user, res, `${user.name} ist für ${hours} h gesperrt.`),
        error: () => this.afterBanError(),
      });
  }

  unbanSelected(): void {
    const user = this.selectedUser;
    if (!user || this.banBusy) return;
    this.banBusy = true;
    this.http.post<any>(`/api/admin/players/${encodeURIComponent(user.id)}/unban`, {}).subscribe({
      next: (res) => this.afterBan(user, res, `Sperre von ${user.name} aufgehoben.`),
      error: () => this.afterBanError(),
    });
  }

  private afterBan(user: PlayerRow, res: any, message: string): void {
    user.banUntil = res?.banUntil ?? null;
    user.banReason = res?.banReason ?? null;
    this.banBusy = false;
    this.banMessage = message;
    this.calculateStats();
    this.cd.detectChanges();
  }

  private afterBanError(): void {
    this.banBusy = false;
    this.banMessage = 'Das hat nicht geklappt – bitte nochmal versuchen.';
    this.cd.detectChanges();
  }

  calculateStats(): void {
    this.totalUsers = this.users.length;
    this.activeUsers = this.users.filter((u) => u.active).length;
    this.bannedUsers = this.users.filter((u) => this.isBanned(u)).length;
  }

  applyFilters(): void {
    const q = this.search.trim().toLowerCase();
    this.filteredUsers = this.users
      .filter((u) => !q || u.name.toLowerCase().includes(q) || u.id.toLowerCase().includes(q))
      .sort((a, b) => {
        if (this.orderBy === 'name') return a.name.localeCompare(b.name, 'de');
        if (this.orderBy === 'lastSeen') return (b.lastSeenAt ?? '').localeCompare(a.lastSeenAt ?? '');
        return b.trophies - a.trophies;
      });
  }
}
