import { Component } from '@angular/core';

@Component({
  selector: 'app-challenges',
  standalone: false,
  templateUrl: './challenges.html',
  styleUrl: './challenges.css',
})
export class Challenges {
  challenges = [
    { title: '30 Day Fitness', participants: 120 },
    { title: 'Code Challenge', participants: 80 },
  ];
}
