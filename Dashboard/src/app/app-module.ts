import { NgModule, provideBrowserGlobalErrorListeners } from '@angular/core';
import { BrowserModule, provideClientHydration, withEventReplay } from '@angular/platform-browser';
import { HttpClientModule } from '@angular/common/http';

import { AppRoutingModule } from './app-routing-module';
import { App } from './app';
import { Layout } from './core/layout/layout';
import { Header } from './core/header/header';
import { Dashboard } from './features/dashboard/dashboard';
import { Users } from './features/users/users';
import { Challenges } from './features/challenges/challenges';
import { Erd } from './features/erd/erd';
import { FormsModule } from '@angular/forms';

@NgModule({
  declarations: [App, Layout, Header, Dashboard, Users, Challenges, Erd],
  imports: [BrowserModule, AppRoutingModule, FormsModule, HttpClientModule],
  providers: [provideBrowserGlobalErrorListeners(), provideClientHydration(withEventReplay())],
  bootstrap: [App],
})
export class AppModule {}
