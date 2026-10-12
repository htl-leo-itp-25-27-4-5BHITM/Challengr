# TestFlight: Schritt-für-Schritt (Stand 12. Oktober 2026)

Ergänzt `TESTFLIGHT_SECURITY_CHECKLIST.md`. Der Code ist fertig; hier stehen die Handgriffe bis zum öffentlichen Link.

## Erledigt

- Projekt liegt unter `~/Developer/ChallengrProjekt` (nicht mehr im iCloud-Desktop).
- Datenschutzerklärung mit Verantwortlichem und Kontakt `challengrapp.official@gmail.com`.
- Keycloak (Realm `challengr`): Rolle `admin` (an Benutzer `test`), Client `challengr-dashboard`
  (Public, PKCE S256), `challengr-admin-api` darf Benutzer verwalten (`manage-users`, `view-users`).
- Datenbank-Backup vom 12.10. in `~/Developer/ChallengrProjekt/Backups/`.

## 1. Neue Passwörter (Backend startet sonst nicht)

Das Backend läuft erst wieder, wenn Postgres kein Standard-Passwort mehr hat.

```bash
cd ~/Developer/ChallengrProjekt/Challengr
./scripts/rotate-secrets.sh
```

Das Skript setzt neue Passwörter für Postgres und den Keycloak-Admin, legt den Prüfer-Account
`applereview` an, speichert alles im Schlüsselbund ("Challengr Leo Cloud …") und startet Keycloak
und Backend neu. Danach: Keycloak-Admin-Konsole mit dem neuen Passwort öffnen und unter
*Users → admin → Required user actions* „Configure OTP“ setzen (2FA).

## 2. Deployen

```bash
./scripts/deploy-cloud.sh both
```

Prüfen:
- `curl -i https://it220257.cloud.htl-leonding.ac.at/api/players/nearby` → **401**
- `https://it220257.cloud.htl-leonding.ac.at/datenschutz.html` zeigt die Erklärung
- Dashboard öffnen → Keycloak-Login mit `test` → Daten sichtbar
- `kubectl -n student-it220257 rollout restart deployment/challengr-backend` → Spieler sind noch da

## 3. App hochladen

Vorbereitet: Release-Builds haben die Bundle-ID **`at.htl.leonding.challengr.app`** (Debug bleibt
`…challengr.binder` fürs Entwickeln), Version 1.0, Privacy-Manifest und Exportangaben sind drin.

1. Apple Developer Program kaufen: https://developer.apple.com/programs/enroll/ (Individual, 99 €/Jahr).
2. Team-ID notieren: https://developer.apple.com/account → *Membership details* (10 Zeichen).
3. Xcode → *Settings → Accounts* → mit derselben Apple-ID anmelden.
4. https://appstoreconnect.apple.com → *Meine Apps → +* → Neue App: Plattform iOS, Name „Challengr“,
   Sprache Deutsch, Bundle-ID `at.htl.leonding.challengr.app` (erscheint nach Schritt 5 einmal registriert
   in der Liste; falls noch nicht: in Xcode einmal mit dem Team archivieren oder unter
   developer.apple.com → *Identifiers* anlegen), SKU z. B. `challengr-ios`.
5. Hochladen:
   ```bash
   ./scripts/upload-testflight.sh <TEAM_ID>
   ```
   Alternativ in Xcode: Team unter *Signing* wählen → *Any iOS Device* → *Product → Archive* → *Distribute App*.
6. *TestFlight → Test Information*: Beschreibung, Feedback-E-Mail `challengrapp.official@gmail.com`,
   Datenschutz-URL `https://it220257.cloud.htl-leonding.ac.at/datenschutz.html`, Anmeldedaten
   `applereview` (Passwort: `security find-generic-password -s "Challengr Apple-Prüfer-Account" -w`),
   Hinweis: „Battles brauchen einen zweiten Spieler in der Nähe; Quiz-Show und Einstellungen sind einzeln ansehbar.“
7. Beim ersten Build fragt TestFlight nach Exportbestimmungen: die App nutzt nur HTTPS → keine
   Verschlüsselung angeben (ist schon im Build hinterlegt).

## 4. Intern testen (Checkliste Teil D)

Interne Tester (bis 100 Personen aus eurem App-Store-Connect-Team) brauchen keine Apple-Prüfung.
Mit zwei iPhones: Registrieren, 500 m Abstand, Unsichtbar, Quiz-Show, Friendly, Blockieren,
Konto löschen, Backend-Neustart.

## 5. Organisatorisch (Teil C)

Zustimmung der Schule, Leo-Cloud-Nutzung klären, Ansprechperson festlegen, tägliches Backup
(z. B. Kubernetes-CronJob mit `pg_dump`).

## 6. Öffentlicher Link

*TestFlight → Externe Tester* → Gruppe „Schule“ → Build hinzufügen → zur Beta-Prüfung einreichen
(1–2 Tage) → danach öffentlichen Link aktivieren, Tester-Limit setzen, „ab 14 Jahren“ angeben.
