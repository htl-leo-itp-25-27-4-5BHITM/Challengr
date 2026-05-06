import { Component, OnInit } from '@angular/core';

@Component({
  selector: 'app-users',
  templateUrl: './users.html',
  standalone: false,
  styleUrls: ['./users.css'],
})
export class Users implements OnInit {
  users: any[] = [];

  totalUsers = 0;
  activeUsers = 0;
  inactiveUsers = 0;

  ngOnInit() {
    this.loadUsers();
  }

  async loadUsers() {
    try {
      const res = await fetch('https://it220257.cloud.htl-leonding.ac.at/api/players');

      if (!res.ok) {
        throw new Error('API Fehler: ' + res.status);
      }

      const data = await res.json();

      this.users = data.map((u: any) => ({
        id: u.id,
        name: u.name,
        status: this.getStatus(u),
      }));

      this.calculateStats();
    } catch (err) {
      console.error('Fehler beim Laden:', err);
    }
  }

  getStatus(user: any): string {
    return user.points > 0 ? 'active' : 'inactive';
  }

  calculateStats() {
    this.totalUsers = this.users.length;
    this.activeUsers = this.users.filter((u) => u.status === 'active').length;
    this.inactiveUsers = this.users.filter((u) => u.status === 'inactive').length;
  }
}
