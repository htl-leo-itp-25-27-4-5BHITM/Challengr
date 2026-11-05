import { NgModule } from '@angular/core';
import { RouterModule, Routes } from '@angular/router';

import { Dashboard } from './features/dashboard/dashboard';
import { Users } from './features/users/users';
import { Challenges } from './features/challenges/challenges';
import { Erd } from './features/erd/erd';
import { Reports } from './features/reports/reports';
import { Feedback } from './features/feedback/feedback';
import { System } from './features/system/system';
import { Quiz } from './features/quiz/quiz';
import { Events } from './features/events/events';
import { Spots } from './features/spots/spots';

const routes: Routes = [
  { path: '', component: Dashboard },
  { path: 'users', component: Users },
  { path: 'challenges', component: Challenges },
  { path: 'erd', component: Erd },
  { path: 'reports', component: Reports },
  { path: 'feedback', component: Feedback },
  { path: 'system', component: System },
  { path: 'quiz', component: Quiz },
  { path: 'events', component: Events },
  { path: 'spots', component: Spots },
  { path: '**', redirectTo: '' },
];

@NgModule({
  imports: [RouterModule.forRoot(routes)],
  exports: [RouterModule]
})
export class AppRoutingModule { }
