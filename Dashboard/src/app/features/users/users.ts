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

  totalUsers = 0;
  activeUsers = 0;
  inactiveUsers = 0;



constructor(
  private http: HttpClient,
  private cd: ChangeDetectorRef
) {}

ngOnInit() {
  this.http.get<any[]>('/api/players').subscribe((data) => {
    this.users = data.map(u => ({
      id: u.id,
      name: u.name,
      status: u.points > 0 ? 'active' : 'inactive',
    }));

    this.calculateStats();
    this.cd.detectChanges();
  });
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
