import { NgModule, inject, provideAppInitializer, provideBrowserGlobalErrorListeners } from '@angular/core';
import { BrowserModule, provideClientHydration, withEventReplay } from '@angular/platform-browser';
import { HTTP_INTERCEPTORS, HttpClientModule } from '@angular/common/http';
import { AuthInterceptor } from './core/auth/auth.interceptor';
import { AuthService } from './core/auth/auth.service';

import { AppRoutingModule } from './app-routing-module';
import { App } from './app';
import { Layout } from './core/layout/layout';
import { Header } from './core/header/header';
import { Icon } from './core/icon/icon';
import { Dashboard } from './features/dashboard/dashboard';
import { BarChart, HBarList, TrendChart } from './features/dashboard/charts';
import { Users } from './features/users/users';
import { Challenges } from './features/challenges/challenges';
import { Erd } from './features/erd/erd';
import { Reports } from './features/reports/reports';
import { Feedback } from './features/feedback/feedback';
import { System } from './features/system/system';
import { Quiz } from './features/quiz/quiz';
import { Events } from './features/events/events';
import { Spots } from './features/spots/spots';
import { FormsModule } from '@angular/forms';

@NgModule({
  declarations: [App, Layout, Header, Icon, Dashboard, TrendChart, BarChart, HBarList, Users, Challenges, Erd, Reports, Feedback, System, Quiz, Events, Spots],
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
