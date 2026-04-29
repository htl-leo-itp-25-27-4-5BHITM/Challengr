import { Component } from '@angular/core';

@Component({
  selector: 'app-users',
  standalone: false,
  templateUrl: './users.html',
  styleUrl: './users.css',
})
export class Users {
  users = [
    { name: 'Max', status: 'active' },
    { name: 'Anna', status: 'inactive' },
    { name: 'John', status: 'active' },
  ];
}
