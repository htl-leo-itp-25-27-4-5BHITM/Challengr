import { NgModule, inject, provideAppInitializer, provideBrowserGlobalErrorListeners } from '@angular/core';
import { BrowserModule, provideClientHydration, withEventReplay } from '@angular/platform-browser';
import { HTTP_INTERCEPTORS, HttpClientModule } from '@angular/common/http';
import { AuthInterceptor } from './core/auth/auth.interceptor';
import { AuthService } from './core/auth/auth.service';

import { AppRoutingModule } from './app-routing-module';
import { App } from './app';
import { Layout } from './core/layout/layout';
import { Header } from './core/header/header';
import { Dashboard } from './features/dashboard/dashboard';
import { Users } from './features/users/users';
import { Challenges } from './features/challenges/challenges';
import { Erd } from './features/erd/erd';
import { Reports } from './features/reports/reports';
import { FormsModule } from '@angular/forms';

@NgModule({
  declarations: [App, Layout, Header, Dashboard, Users, Challenges, Erd, Reports],
  imports: [BrowserModule, AppRoutingModule, FormsModule, HttpClientModule],
  providers: [
    provideBrowserGlobalErrorListeners(),
    provideClientHydration(withEventReplay()),
    // Admin-Login über Keycloak, bevor das Dashboard Daten lädt (Checkliste A3)
    provideAppInitializer(() => inject(AuthService).init()),
    { provide: HTTP_INTERCEPTORS, useClass: AuthInterceptor, multi: true },
  ],
  bootstrap: [App],
})
export class AppModule {}
