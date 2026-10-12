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

1. Bezahlter Apple Developer Account (99 €/Jahr). Mit „Personal Team“ geht kein Upload.
2. Xcode, Projekt `Swift/Challengr`: *Signing* → bezahltes Team, endgültige Bundle-ID (z. B. `at.htl.leonding.challengr`).
3. *General*: Version `1.0`, Build `1` (jeder weitere Upload: Build +1).
4. Ziel **Any iOS Device** → *Product → Archive* → *Distribute App → App Store Connect → Upload*.
5. App Store Connect → *Meine Apps → +* (gleiche Bundle-ID), falls noch nicht vorhanden.
6. *TestFlight → Test Information*: Beschreibung, Feedback-E-Mail, Datenschutz-URL
   `https://it220257.cloud.htl-leonding.ac.at/datenschutz.html`, Anmeldedaten `applereview`
   (Passwort im Schlüsselbund „Challengr Apple-Prüfer-Account“), Hinweis: „Battles brauchen einen
   zweiten Spieler in der Nähe; Quiz-Show und Einstellungen sind einzeln ansehbar.“

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
