import { NgModule } from '@angular/core';
import { RouterModule, Routes } from '@angular/router';

import { Dashboard } from './features/dashboard/dashboard';
import { Users } from './features/users/users';
import { Challenges } from './features/challenges/challenges';
import { Erd } from './features/erd/erd';

const routes: Routes = [
  { path: '', component: Dashboard },
  { path: 'users', component: Users },
  { path: 'challenges', component: Challenges },
  { path: 'erd', component: Erd },
  { path: '**', redirectTo: '' },
];

@NgModule({
  imports: [RouterModule.forRoot(routes)],
  exports: [RouterModule]
})
export class AppRoutingModule { }
