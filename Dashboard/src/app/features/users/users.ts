import { Component, OnInit } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { ChangeDetectorRef } from '@angular/core';

@Component({
  selector: 'app-users',
  templateUrl: './users.html',
  standalone: false,
  styleUrls: ['./users.css'],
})
export class Users implements OnInit {

  users: any[] = [];
  filteredUsers: any[] = [];

  totalUsers = 0;
  activeUsers = 0;
  inactiveUsers = 0;

  selectedUser: any = null;

  banHours = 24;
  banReason = '';
  banBusy = false;

  search = '';

  orderBy = 'name';
  orderDirection: 'asc' | 'desc' = 'asc';

  constructor(
    private http: HttpClient,
    private cd: ChangeDetectorRef,
  ) {}

  ngOnInit() {

    this.http.get<any[]>('/api/players').subscribe((data) => {

      this.users = data.map((u) => ({
        id: u.id,
        name: u.name,
        points: u.points,
        banUntil: u.banUntil ?? null,
        banReason: u.banReason ?? null,
        status: u.points > 0 ? 'active' : 'inactive',
      }));

      this.filteredUsers = [...this.users];

      this.calculateStats();
      this.applyFilters();

      this.cd.detectChanges();
    });
  }

  isBanned(user: any): boolean {
    if (!user?.banUntil) return false;
    const t = new Date(user.banUntil).getTime();
    return Number.isFinite(t) && t > Date.now();
  }

  banSelected() {
    if (!this.selectedUser || this.banBusy) return;
    const hours = Number(this.banHours);
    if (!Number.isFinite(hours) || hours <= 0) return;

    this.banBusy = true;
    const durationSeconds = Math.round(hours * 3600);

    this.http
      .post<any>(`/api/admin/players/${encodeURIComponent(this.selectedUser.id)}/ban`, {
        durationSeconds,
        reason: this.banReason || null,
      })
      .subscribe({
        next: (res) => {
          this.selectedUser.banUntil = res?.banUntil ?? null;
          this.selectedUser.banReason = res?.banReason ?? null;
          // mirror back into list
          const u = this.users.find((x) => x.id === this.selectedUser.id);
          if (u) {
            u.banUntil = this.selectedUser.banUntil;
            u.banReason = this.selectedUser.banReason;
          }
          this.cd.detectChanges();
          this.banBusy = false;
        },
        error: () => {
          this.banBusy = false;
        },
      });
  }

  unbanSelected() {
    if (!this.selectedUser || this.banBusy) return;
    this.banBusy = true;

    this.http
      .post<any>(`/api/admin/players/${encodeURIComponent(this.selectedUser.id)}/unban`, {})
      .subscribe({
        next: (res) => {
          this.selectedUser.banUntil = res?.banUntil ?? null;
          this.selectedUser.banReason = res?.banReason ?? null;
          const u = this.users.find((x) => x.id === this.selectedUser.id);
          if (u) {
            u.banUntil = this.selectedUser.banUntil;
            u.banReason = this.selectedUser.banReason;
          }
          this.cd.detectChanges();
          this.banBusy = false;
        },
        error: () => {
          this.banBusy = false;
        },
      });
  }

  selectUser(user: any) {
    this.selectedUser = user;
  }

  getStatus(user: any): string {
    return user.points > 0 ? 'active' : 'inactive';
  }

  calculateStats() {

    this.totalUsers = this.users.length;

    this.activeUsers = this.users.filter(
      (u) => u.status === 'active'
    ).length;

    this.inactiveUsers = this.users.filter(
      (u) => u.status === 'inactive'
    ).length;
  }

  applyFilters() {

    this.filteredUsers = this.users.filter((user) => {

      const value = this.search.toLowerCase();

      return (
        user.name.toLowerCase().includes(value) ||
        user.id.toString().includes(value)
      );

    });

    this.filteredUsers.sort((a, b) => {

      let compareA: any;
      let compareB: any;

      if (this.orderBy === 'name') {

        compareA = a.name.toLowerCase();
        compareB = b.name.toLowerCase();

      } else {

        compareA = a.points;
        compareB = b.points;

      }

      if (compareA < compareB) {
        return this.orderDirection === 'asc' ? -1 : 1;
      }

      if (compareA > compareB) {
        return this.orderDirection === 'asc' ? 1 : -1;
      }

      return 0;
    });
  }
}
