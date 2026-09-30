# USABILITY & UX REPORT – Challengr iOS (Phase 5)

> **Grundlage:**
> - echte Screenshots aus UI-Testläufen (iPhone 17 Pro, iPhone 16e, iPad Pro 11", hell/dunkel, größte Schrift, Querformat)
> - Apples automatischer Accessibility-Audit (`performAccessibilityAudit`, 9 Screens, 218 Befunde)
> - Code-Analyse
>
> **Nicht enthalten:** keine echte Nutzerstudie. Aussagen zu Spielspaß und Frust sind als **Hypothesen** mit Testaufgaben für einen späteren Test mit echten Spielern formuliert (Abschnitt G).
>
> **Bewertung je Befund:**
> - **Schwere:** kritisch / hoch / mittel / niedrig
> - **Wirkung:** was der Spieler erlebt
> - **Reichweite:** wie viele Spieler bzw. wie oft

---

## A. Erste Nutzung (First-Time User Experience)

| Frage | Bewertung | Beleg |
|---|---|---|
| Versteht man sofort, worum es geht? | **Gut.** Login-Screen („Real-Life Battles. Überall.“) und 3-seitiges Onboarding erklären die Kernschleife: Spieler finden → herausfordern → Punkte → Shop. | GP01_onboarding_1–3 |
| Ist klar, wie man startet? | **Teilweise.** Nach dem Onboarding sieht man die Karte, aber keinen Hinweis „Tippe auf einen Spieler“. Ist niemand in der Nähe, steht nur „Noch keine Spieler in deiner Nähe“, ohne nächsten Schritt (z. B. Freunde einladen). | SC07_offline_map |
| Sind die Regeln verständlich? | **Teilweise.** Wie das Ergebnis bei normalen Battles zustande kommt (beide stimmen ab, Konflikt kostet ab dem 3. Mal Punkte), wird nirgends erklärt. Die Anfrage verfällt nach 60 s, ohne dass das sichtbar ist. | GP09, GP12, GP16 |
| Einstiegshürden | **Hoch.** Ohne Keycloak-Schulkonto kein Zugang. Kein Token-Speicher → **bei jedem App-Start neu anmelden**. | Code `KeycloakAuthService` |

## B. Navigation und Interaktion

| ID | Befund | Schwere | Wirkung | Reichweite | Beleg |
|---|---|---|---|---|---|
| UX-01 | Spieler-Popup lässt sich **nicht durch Tippen daneben** schließen, nur durch erneutes Tippen auf denselben Pin. Nach jeder Nähe-Aktualisierung (4 s) funktioniert auch das nicht mehr zuverlässig (CA-06). | mittel | Popup verdeckt die Karte, Spieler wissen nicht, wie es weggeht | jeder, der einen Spieler antippt | SC06 |
| UX-02 | **Überlappende Pins**: Bei vielen Spielern überlagern sich die Pins, und nur wenige Namen sind sichtbar. Alle Gegner haben dasselbe Symbol, der eigene Pin wird verdeckt. Kein Clustering. | mittel | falscher Spieler angetippt, eigener Standort schwer zu finden | Schultest mit vielen Spielern | LAY_iPhone16e_1_map, SC05 |
| UX-03 | Der **Profil-Button** (Avatar unten rechts) ist nicht als Profil erkennbar, und Freunde sind nur über das Profil erreichbar (2 Ebenen). | niedrig | Freunde-Funktion wird übersehen | alle | RT02 |
| UX-04 | **Zwei Buttons öffnen den Shop** (Tasche und Punkte-Chip). Der Pokal-Button öffnet die Trophy Road, der Pokal-Chip den Shop. Gleiches Symbol, unterschiedliche Ziele. | niedrig | Verwechslung | alle | GP03 |
| UX-05 | „Schließen“ im Wissens- und Check-In-Battle beendet das Battle für den Gegner nicht (CA-05). Man kann ein Battle „verlassen“, ohne aufzugeben. | mittel | Gegner wartet bis zu 10 min | jedes Wissens-/Check-In-Battle | GP13 |
| UX-06 | Doppel-Tap-Schutz funktioniert: Doppelter Tap auf SENDEN erzeugt eine Anfrage, auf das Zahnrad ein Sheet. | positiv | – | – | GP08, RT03 |

## C. Gameplay-Erlebnis

| ID | Befund | Schwere | Wirkung | Reichweite | Beleg |
|---|---|---|---|---|---|
| UX-07 | **Wissens-Battle: keine Rückmeldung nach falscher Antwort.** Der Button bleibt grün, obwohl er gesperrt ist; „warte auf Ergebnis“ bleibt stehen. Liegen beide falsch, passiert gar nichts mehr (BUG-03). | hoch | Spieler glauben, die App hängt | häufig (2 falsche Antworten) | GP14 |
| UX-08 | **Anfrage eines Dritten während eines Battles** stapelt Overlays: „Ergebnis wird berechnet“ liegt über einem fremden Popup, das Ergebnis kommt nie (BUG-02). | hoch | Spiel steckt fest | jeder Battle, sobald ein Dritter herausfordert | GP17 |
| UX-09 | **Keine Anzeige der Restzeit** bei eingehender Anfrage (60 s) und beim Warten auf den Gegner-Messwert (bis 45 s). | mittel | Überraschendes Verschwinden, gefühlte Hänger | jede Anfrage | GP09, GP16 |
| UX-10 | **Konflikt und Unentschieden sehen aus wie eine Niederlage** („NIEDERLAGE“, „KOPF HOCH“), obwohl niemand verloren hat. | mittel | fühlt sich unfair an | Konflikte, Gleichstand | GP12 |
| UX-11 | **Gegner hat immer denselben Avatar** (playerGirl) in Battle und Ergebnis, egal welchen Charakter er gewählt hat. Auf der Karte sehen alle Gegner gleich aus. | niedrig | Charakterwahl hat für andere keinen Sinn | alle Battles | GP10, GP11 |
| UX-12 | **Offline ohne Hinweis:** Die Karte zeigt „Noch keine Spieler in deiner Nähe“ und **0 Punkte**. Nur der Shop meldet „nicht erreichbar“. | mittel | Spieler denkt, seine Punkte sind weg | jede Verbindungsstörung | SC07 |
| UX-13 | **Neustart verliert den Spielzustand** (eigene Anfrage, laufendes Battle). | hoch | Gegner wartet ins Leere | App-Wechsel mit Speicherdruck, Absturz | FU01, FU02 |
| UX-14 | Freunde-Seite ist **ohne Standort komplett leer** („Standort benötigt …“), obwohl Freundesliste, Anfragen und QR-Code keinen Standort brauchen. | mittel | Freunde-Funktion unbenutzbar | beim Start, bei verweigertem Standort | RT02_friends |
| UX-15 | Unterhaltsame, klare Ergebnis-Screens mit Konfetti, Punkteänderung und Messwerten (Sprint). | positiv | – | – | GP10, GP15 |

## D. Visuelles Design

| ID | Befund | Schwere | Beleg |
|---|---|---|---|
| UX-16 | **Battle-Screen läuft rechts über den Rand** (17 Pro und 16e): Spielerkarten und „AUFGEBEN“ abgeschnitten, Titel wird von der oberen Karte überdeckt, der eigene Name klebt am Rand. | mittel | GP10_battle_view, LAY_iPhone16e_3_battle |
| UX-17 | **Dark Mode unbrauchbar:** Alle Markenfarben (Gelb, Grün, Rot, Schwarz, Weiß) sind im Asset-Katalog für Dark Mode auf **Weiß** gesetzt. Dadurch ist „CHALLENGE!“ Weiß auf Weiß, der gelbe Challenge-Hintergrund und der grüne „ANNEHMEN“-Button werden weiß, und die Karten-Buttons verblassen. | hoch | LAY_17Pro-dark-XXXL_* |
| UX-18 | **Kontrast:** Weiß auf Gelb (FITNESS-Button), Rot auf Rot (Voting-Kachel des Gegners), Grün und Rot auf Grau (Punkte im Ergebnis), Login-Texte mit 55 % Deckkraft. Der Audit meldet **34 ungenügende und 21 knappe** Kontraste. | mittel | GP04, GP10_voting, GP10_win_screen, A11Y_* |
| UX-19 | **iPad**: Layout ist auf iPhone ausgelegt, große leere Flächen, Name überlappt die VS-Box. **Querformat** ist erlaubt, aber nicht gestaltet (Pokal-Button zwischen den Pins). | niedrig | LAY_iPadPro11_*, LAY_*_landscape_* |
| UX-20 | **Sprachmix / Begriffe:** „TAP TO VOTE“, „Battle“, „Trash Talk“ neben Deutsch; **Punkte vs. Trophäen** (Trophy Road „24 TROPHÄEN“, Profil „24 PUNKTE“). Rangname falsch geschrieben: „Quitttter“ (DB: „Quittttter“, Doku: „Quitter“). | niedrig | GP10_voting, RT02_* |
| UX-21 | **Kein App-Icon** (Platzhalter auf Homescreen und in Mitteilungen). | hoch (Außenwirkung) | GP19 |
| UX-22 | Profil: Badges am unteren Rand abgeschnitten, Status „Online“ ist fest eingebaut, Punkteverlauf mit einem einzelnen Punkt ohne Kontext. | niedrig | RT02_profile |
| UX-23 | Einheitliche, gut erkennbare Markensprache (Farben, abgerundete Karten, fette Typo) im hellen Modus. | positiv | – |

## E. Accessibility

Automatisierter Audit auf 9 Screens: **218 Befunde** (Rohdaten: `logs/08_accessibility_audit_raw.jsonl`).

| Art | Anzahl | Typische Beispiele |
|---|---|---|
| Dynamic Type nicht unterstützt | 90 (+3 teilweise) | alle Texte nutzen `.system(size:)` mit fester Größe |
| Label nicht menschenlesbar | 62 | VoiceOver liest „gearshape.fill“, „person.fill“, „trophy.fill“, „playerBoy“, „bolt.shield.fill“ |
| Kontrast ungenügend | 34 | Login-Features, „NIEDERLAGE“, „±Punkte“, „CHALLENGE!“ |
| Kontrast knapp | 21 | Profil-Kacheln, Zähler |
| Touch-Fläche zu klein | 6 | „ÜBERSPRINGEN“, Pfeil zum Einklappen (heißt „Back“) |
| Text abgeschnitten | 2 | Badges im Profil |

Weitere beobachtete Punkte:
- Der **Profil-Button heißt „playerBoy“**, mit Freundschafts-Badge nur noch **„1“** (Hierarchie-Dump).
- Hinter modalen Overlays (eingehende Challenge) bleiben die Karten-Buttons im Accessibility-Baum erreichbar. VoiceOver kann Aktionen *hinter* dem Popup auslösen.
- Bei größter Systemschrift bleibt die UI klein (kein Dynamic Type), aber der Challenge-Text im Popup wird trotzdem **auf eine Zeile gekürzt** („Wer hält länger einen Plank (Unter…“) → BUG-14.
- Farben tragen Bedeutung ohne zweites Merkmal (Rang nur über Ringfarbe, Sieger/Verlierer nur Grün/Rot). Das ist für Farbfehlsichtige problematisch.
- Reduce Motion wird nicht berücksichtigt (Konfetti, pulsierende Animationen, Wackeln im Niederlage-Screen).

## F. Geräte und Zustände

| Zustand | Ergebnis | Beleg |
|---|---|---|
| iPhone 16e (klein) | Karte, Popup, Shop, Ergebnis lesbar; **Battle-Screen läuft über** | LAY_iPhone16e_* |
| iPhone 17 Pro | wie oben | LAY_iPhone17Pro_* |
| iPad Pro 11" | nutzbar, aber nicht angepasst | LAY_iPadPro11_* |
| Querformat | nutzbar, nicht gestaltet | LAY_*_landscape_* |
| Dark Mode | **unbrauchbar** in Popups und Buttons | LAY_17Pro-dark-XXXL_* |
| Größte Systemschrift | keine Wirkung auf die meisten Texte, einzelne Kürzungen | LAY_17Pro-dark-XXXL_2_incoming |
| Offline | kein Absturz, aber irreführend (0 Punkte) | SC07_* |
| Hintergrund | Zustand bleibt, Mitteilung kommt | GP18, GP19 |

## G. Hypothesen für einen Test mit echten Spielern (nicht durchgeführt)

| # | Hypothese | Aufgabe für Testpersonen | Messgröße |
|---|---|---|---|
| H1 | Neue Spieler finden ohne Hilfe heraus, wie man jemanden herausfordert. | „Fordere die Person neben dir heraus.“ | Zeit bis zum Senden, Fehlklicks |
| H2 | Spieler verstehen nicht, warum sie nach einem Konflikt „verloren“ haben. | Konflikt herbeiführen, danach fragen „Wer hat gewonnen?“ | Anteil richtiger Antworten |
| H3 | Bei 10+ Spielern auf engem Raum tippen Spieler den falschen Gegner an. | „Fordere Max heraus“ in einer Gruppe | Fehlerquote |
| H4 | Spieler bemerken den 60-s-Ablauf nicht und sind überrascht. | Anfrage erst nach 50 s beantworten lassen | Überraschung/Frust (1–5) |
| H5 | Die Freunde-Funktion wird ohne Hinweis nicht gefunden. | „Füge die Person als Freund hinzu.“ | Erfolgsquote, Zeit |
| H6 | Das Abstimmen nach „Geschafft“ fühlt sich fair an. | 5 Battles spielen, danach Fragebogen | Fairness-Wert (1–5) |
