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
        email: u.email,
        level: u.level,
        createdAt: u.createdAt,
        status: u.points > 0 ? 'active' : 'inactive',
      }));

      this.filteredUsers = [...this.users];

      this.calculateStats();
      this.applyFilters();

      this.cd.detectChanges();
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
