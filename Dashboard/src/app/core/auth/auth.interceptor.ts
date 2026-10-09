import { Injectable } from '@angular/core';
import { HttpErrorResponse, HttpEvent, HttpHandler, HttpInterceptor, HttpRequest } from '@angular/common/http';
import { Observable, catchError, from, switchMap, throwError } from 'rxjs';
import { AuthService } from './auth.service';

/** Hängt das Keycloak-Token an alle Backend-Aufrufe (/api/...). Bei 401 → neu anmelden. */
@Injectable()
export class AuthInterceptor implements HttpInterceptor {
  constructor(private auth: AuthService) {}

  intercept(req: HttpRequest<unknown>, next: HttpHandler): Observable<HttpEvent<unknown>> {
    if (!req.url.startsWith('/api') && !req.url.includes('/api/')) {
      return next.handle(req);
    }
    return from(this.auth.token()).pipe(
      switchMap((token) => next.handle(token ? req.clone({ setHeaders: { Authorization: `Bearer ${token}` } }) : req)),
      catchError((err: unknown) => {
        if (err instanceof HttpErrorResponse && err.status === 401) {
          this.auth.login();
        }
        return throwError(() => err);
      }),
    );
  }
}
