import { NgModule, provideBrowserGlobalErrorListeners } from '@angular/core';
import { BrowserModule, provideClientHydration, withEventReplay } from '@angular/platform-browser';

import { AppRoutingModule } from './app-routing-module';
import { App } from './app';
import { Layout } from './core/layout/layout';
import { Header } from './core/header/header';
import { Dashboard } from './features/dashboard/dashboard';
import { Users } from './features/users/users';
import { Challenges } from './features/challenges/challenges';

@NgModule({
  declarations: [App, Layout, Header, Dashboard, Users, Challenges],
  imports: [BrowserModule, AppRoutingModule],
  providers: [provideBrowserGlobalErrorListeners(), provideClientHydration(withEventReplay())],
  bootstrap: [App],
})
export class AppModule {}
