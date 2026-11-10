# Android in der Fable-Woche (10.–17.11.2026)

Ziel: Bis **17.11.** (Ende des kostenlosen Fable-Zugangs) läuft eine **spielbare Android-App**, mit der Android-Spieler
gegen iPhone-Spieler antreten – gleiches Backend, gleiche Liga. Kein Gleichstand mit iOS, sondern der **Kern**.
Grundlage: `docs/projekt/Android-Roadmap.md` (Technik, Fairness, Schnittstellen). Diese Datei sagt, **was wann** passiert.

---

## 1. Umfang bis 17.11.

**Drin (Android-Kern):**
- Login über Keycloak (PKCE), angemeldet bleiben, Spieler anlegen, Lade-Screen
- Cartoon-Karte (MapLibre + `ToonMapStyle.json`), eigene Figur, Spieler in der Nähe als Figuren (Sprite-Sheets), Check-in-Orte
- Herausfordern: Liga Quiz-Show, Liga Real-Life, Friendly (Challenge wählen **oder** Friendly-Quiz), Anfrage annehmen/ablehnen, Aufgeben
- **Übungsmodus gegen den Trainings-Dummy** – damit kann man Android allein testen
- Quiz-Show in 2D (4 Fragen, Tempo-Punkte, Auflösung)
- Gemessene Challenges: Schreien, Schütteln, Reaktions-Test, Zeitgefühl, Kompass, Länder-Kompass, Sprint, Check-in-Spot (mit Erklär-Bildschirm)
- Ergebnis-Screen in 2D (Sieger, Trophäen, Messwerte)
- Rundherum minimal: Profil (Name ändern, unsichtbar), Rangliste, Figurenwahl in 2D, Emotes, **Melden/Blockieren und Konto löschen** (Pflicht für Stores)

**Bewusst später (nach der Fable-Woche, mit Opus):** 3D-Figuren und 3D-Siegerehrung, Liegestütze (ML Kit), Sticker,
Story/Steckbriefe, Aufgaben und Events, Trophy Road, Freunde, Push-Mitteilungen, Kopfgeld-/Erzfeind-/Chaos-Anzeige,
Figuren-Stufen, Riss-Wächter, Shop. Das Backend schickt diese Felder schon mit – die Android-App ignoriert sie vorerst.

---

## 2. Was du (Basti) vorher erledigst

1. **Keycloak-Client anlegen** (Claude darf Keycloak nicht ändern): Admin-Konsole → Realm `challengr` → Clients → *Create*
   - Client ID `challengr-android`, Client authentication **aus** (public), Standard Flow **an** – wie `challengr-ios` (`k8s/README.md`)
   - Valid Redirect URIs: `com.challengrapp.challengr:/callback`, Web Origins `*`
   - Am einfachsten: den Client `challengr-ios` öffnen und alles Weitere (Advanced → PKCE, Tab *Client scopes* mit `offline_access`)
     genauso einstellen – die iOS-App nutzt PKCE und `offline_access`, das Android-Pendant braucht dasselbe.
2. **Testgerät**: ein echtes Android-Handy mit USB-Debugging (Einstellungen → Über das Telefon → 7× Build-Nummer → Entwickleroptionen → USB-Debugging). Der Emulator aus Android Studio reicht für fast alles, aber Mikrofon, Kompass und GPS nur am echten Gerät.
3. Android Studio einmal öffnen und Updates/SDK-Lizenzen bestätigen (ist installiert, SDK liegt in `~/Library/Android/sdk`).
4. Für Tester ohne Play-Store-Konto reicht vorerst eine **APK zum Installieren** (Google-Play-Konto für 25 $ erst, wenn es weitergeht).

---

## 3. So arbeitest du mit Fable

- Im Projektordner starten: `claude --model fable` (oder in einer Sitzung `/model fable`). **Fable nur für Android** verwenden, alles andere mit dem normalen Modell.
- Eigener Branch: `feature/android` (von `feature/liga-modus`). Code in `Android/` im Repo.
- **Jeden Tag mit dem Start-Prompt unten beginnen** und den Tagesblock aus Abschnitt 4 dazukopieren.
- Am Ende jedes Tages schreibt Claude den Stand in `docs/projekt/Android-Stand.md` (was läuft, was offen ist, wie man testet). So kann am 18.11. ein normales Modell nahtlos weitermachen.
- Testen: Claude baut und testet im Emulator selbst (Gradle, adb, Screenshots). **Du** testest abends am echten Handy und gegen einen iPhone-Simulator/dein iPhone.
- Deploy/Backend-Änderungen nur wenn nötig und wie immer: erst fragen, Backup vorher. Push nach Rückfrage.

### Start-Prompt (jeden Tag)

```
Wir bauen die Android-Version von Challengr (Kotlin + Jetpack Compose) in Android/, Branch feature/android.
Lies zuerst docs/projekt/Android-Fable-Plan.md, docs/projekt/Android-Roadmap.md und docs/projekt/Android-Stand.md.
Referenz ist die iOS-App in Swift/Challengr/Challengr – gleiche Texte, gleiche Farben, gleicher Ablauf.
Das Backend bleibt unverändert (https://it220257.cloud.htl-leonding.ac.at, lokal Port 8081).
Heute ist Tag <N>: <Tagesblock aus Abschnitt 4 einfügen>.
Arbeite selbstständig bis die Fertig-Kriterien erfüllt sind: bauen, im Emulator testen, Screenshots ansehen,
Unit-Tests für Logik schreiben. Committe nach jedem fertigen Teil (nicht pushen).
Am Ende Android-Stand.md aktualisieren und mir kurz auf Deutsch sagen, was ich am echten Handy testen soll.
```

---

## 4. Tagesplan

| Tag | Datum | Inhalt | Fertig, wenn … |
|---|---|---|---|
| 1 | Mo 10.11. | Projekt `Android/` (Compose, Navigation, Theme Rot `#BA1F33`, Dunkel `#1E000E`, Gelb `#FDD006`, Schrift wie iOS), Login mit AppAuth + PKCE + `offline_access`, Token sicher speichern, HTTP-Client mit Bearer + Erneuerung bei 401, Lade-Screen, `POST /api/players` | App startet im Emulator, Login klappt, nach Neustart noch angemeldet, Spieler existiert im Dashboard |
| 2 | Di 11.11. | WebSocket `/ws/game` (OkHttp, Wiederverbinden), Karte mit MapLibre + `ToonMapStyle.json`, feste Neigung, Drehen/Zoomen, eigener Standort → `PUT /api/players`, `GET /api/players/nearby` → Figuren als Sprites (`*MapSheet.png`), Check-in-Orte (`/api/hotspots`) | Karte sieht aus wie auf iOS, eigene Figur am Standort, andere Spieler erscheinen und bewegen sich |
| 3 | Mi 12.11. | Spieler-Popup, Herausfordern-Dialog (Liga Quiz / Liga Real-Life / Friendly mit Kacheln inkl. Quiz-Show `FRIENDLY_QUIZ`), eingehende Anfrage (annehmen/ablehnen), Warten-Overlay, `battle-result` → Ergebnis-Screen 2D, Aufgeben, Emotes | Android ↔ iOS: Anfrage hin und zurück, Friendly mit „Geschafft“ endet sauber |
| 4 | Do 13.11. | Quiz-Show 2D (`quiz-question`, `quiz-answer`, `quiz-round-result`, Punkte), **Übungsmodus** (Münz-Menü → Üben, `toId: practice-bot`), `ChallengeSeed` + Länderliste bitgenau portieren + **Kreuztest** mit iOS-Werten | Quiz-Show gegen den Dummy komplett spielbar, Seed-Kreuztest grün |
| 5 | Fr 14.11. | Erklär-Bildschirm (20 s Auto-Start, 3 s Countdown, Timer getrennt!), Schrei-Challenge (`AudioRecord`), Schütteln (gleiche Formel wie `MotionManager.swift`), Reaktions-Test, Zeitgefühl | Alle vier gegen den Dummy spielbar, Werte plausibel |
| 6 | Sa 15.11. | Kompass + Länder-Kompass (geografischer Norden mit Deklination), Sprint (Fused Location), Check-in-Spot, Check-in an Orten | Alle Real-Life-Challenges der Liga auf Android spielbar |
| 7 | So 16.11. | Profil (Name ändern, unsichtbar), Rangliste, Figurenwahl 2D (`/characters`, gesperrt/frei), Melden/Blockieren, Konto löschen, Töne | Ein neuer Spieler kommt ohne Hilfe vom Login bis zum ersten Liga-Sieg |
| 8 | Mo 17.11. | Puffer, Fehler aus Basti-Tests, echtes Gerät, Kreuzspiel iOS↔Android in allen Modi, signierte **APK** für Tester, `Android-Stand.md` als Übergabe | APK läuft auf 2 echten Handys, Übergabe vollständig |

Wenn ein Tag länger dauert: **Tag 7 kürzen** (Figurenwahl und Töne nach hinten), nie die Tage 1–4 – ohne die ist nichts spielbar.

---

## 5. Leitplanken für Claude

- Struktur der iOS-App spiegeln (`Logic/`, `Services/`, `Views/` → Kotlin-Packages), gleiche Texte auf Deutsch.
- **Fairness** (Roadmap Abschnitt 3): Seed bitgenau, Kompass auf geografischen Norden, Schütteln mit derselben Formel.
- Neue Felder seit der Roadmap (25.10.) einfach mitparsen oder ignorieren: `bounty`, `characterLevel`, `bountyBonus`,
  `winnerLevelUp`, `secretUnlocked`, `quiz`, `mode` (`FRIENDLY`, `FRIENDLY_QUIZ`, `RANKED_KNOWLEDGE`, `RANKED_REALLIFE`).
  Unbekannte Nachrichten (`boss-*`, `sticker-stock`, `gift-received`) ignorieren, nicht abstürzen.
- Unbekannte Figur-Id → Ersatzfigur (wie `GameCharacter.opponent` auf iOS).
- Keine Tracking-/Werbe-SDKs, keine Analyse-Dienste. Standort nur fürs Spiel, wie auf iOS.
- Keine Schule im App-Namen oder in Texten (Ausnahme: Server-URL).
- Nichts an Backend, Keycloak oder Datenbank ändern ohne Rückfrage.

---

## 6. Risiken

| Risiko | Gegenmittel |
|---|---|
| Login/Redirect klemmt (Keycloak) | Tag 1 zuerst Login, notfalls Basti prüft die Client-Einstellungen |
| MapLibre-Stil sieht anders aus | Stil-JSON 1:1, Schriften/Sprites wie iOS; Screenshot-Vergleich |
| Mikrofone iPhone ↔ Android unterschiedlich laut | Schrei-Challenge zwischen Plattformen vorerst nur im Friendly (Roadmap 7.2) |
| Kompass ungenau | Kalibrier-Hinweis, am echten Gerät prüfen |
| Fable-Zugang endet mitten in einer Aufgabe | täglich committen + `Android-Stand.md` pflegen |
