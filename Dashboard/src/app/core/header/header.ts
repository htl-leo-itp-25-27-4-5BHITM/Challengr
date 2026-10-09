import { Component } from '@angular/core';
import { AuthService } from '../auth/auth.service';

@Component({
  selector: 'app-header',
  standalone: false,
  templateUrl: './header.html',
  styleUrl: './header.css',
})
export class Header {
  constructor(public auth: AuthService) {}

  get initials(): string {
    const name = this.auth.userName || '?';
    return name.slice(0, 2).toUpperCase();
  }

  logout(): void {
    this.auth.logout();
  }
}
