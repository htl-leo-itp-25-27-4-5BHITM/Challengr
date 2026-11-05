Challengr iOS – Notizen
=======================

Sounds (Services/SoundManager.swift)
------------------------------------
- Alle Effekte stehen im enum SoundEffect (Name -> Datei im Ordner Sounds, ohne .mp3).
- Abspielen: SoundManager.shared.play(.purchase)
- Respektiert den Schalter "Soundeffekte" in den Einstellungen (UserDefaults "isSoundEnabled").
- Neue Datei: einfach in Sounds/ legen und im enum eintragen.

Battle-Anfragen
---------------
- Eine Anfrage ist 60 Sekunden gültig (Backend: BattleService.REQUEST_TIMEOUT).
  Danach setzt das Backend den Status EXPIRED und schickt "battle-updated" an beide.
- "Abbrechen" beim Sender schickt CANCELLED; das Popup beim Empfänger verschwindet.
- Offene Anfragen werden nach einem Reconnect erneut zugestellt.

Regeln beim Herausfordern (Backend)
-----------------------------------
- Nicht sich selbst, nur im eigenen Namen, pro Spielerpaar nur eine offene Anfrage.
- Abgelehnt -> "battle-rejected" mit Grund, die App zeigt ein Banner.

Ergebnisse
----------
- battle-result geht nur an die zwei Spieler des Battles und enthält winnerId/loserId.
- Die App entscheidet Sieg/Niederlage über die ID (Namen können doppelt vorkommen).
- Abstimmung schickt winnerId; jeder Spieler hat eine Stimme.
- Mess-Challenges (Sprint, Lautstärke, Kompass, Kamera, Schütteln, Liegestütze) werden
  erst ausgewertet, wenn beide Werte da sind – spätestens 45 s nach dem ersten Wert.
- Ein Battle wird nur einmal ausgewertet (keine doppelten Punkte).

Freundschaftsanfragen (Services/FriendsInboxStore.swift)
--------------------------------------------------------
- Kommen live über WebSocket ("friend-request-created" / "friend-request-updated").
- Banner oben auf der Karte + roter Zähler am Profil-Button.
- Alle 60 s wird zusätzlich nachgeladen, falls ein Event verpasst wurde.

Mitteilungen (Services/NotificationManager.swift)
-------------------------------------------------
- Lokale Mitteilungen, wenn die App im Hintergrund ist (Challenge, Freundschaftsanfrage).
- Nach dem Wechsel in den Hintergrund bleibt die Verbindung ca. 30 s offen.
- Danach schließt iOS die App-Verbindung -> dann kommt nichts mehr an.

Echte Push-Nachrichten (noch offen)
-----------------------------------
Damit Challenges auch bei geschlossener App ankommen, braucht es Remote Push (APNs):
1. Bezahlter Apple-Developer-Account, Capability "Push Notifications" im Target aktivieren.
2. APNs-Key (.p8) im Developer-Portal erzeugen, Key-ID + Team-ID ins Backend (Secret).
3. App: registerForRemoteNotifications(), Device-Token an das Backend schicken
   (z.B. POST /api/players/{id}/push-token) und beim Player speichern.
4. Backend: beim Erstellen eines Battles, wenn der Empfänger keine WebSocket-Session hat,
   eine Push-Nachricht über APNs senden (z.B. mit der Bibliothek "pushy").

Tests
-----
Alles auf einmal (Backend + beide iOS-Projekte):   ./scripts/test-all.sh
Nur Backend:  ./scripts/test-all.sh backend      Nur App:  ./scripts/test-all.sh ios
In Xcode: Cmd+U (Target "ChallengrTests").

App-Tests (ChallengrTests/):
- BattleScreenTests        welche Battle-Ansicht zu welcher Challenge gehört
- BattleLogicTests         Ergebnis gehört zu mir? gewonnen? Abstimmung -> Spieler-ID
- ChallengeLookupTests     Challenge auflösen (Server -> Cache -> Laden), Kategorie-Filter
- GameSocketMessageTests   jede Server-Nachricht -> richtiger Callback
- ModelDecodingTests       JSON vom Backend -> Swift-Modelle
- AppSettingsTests         alle Sound-Dateien vorhanden, Schalter, Backend-URLs

Logik, die getestet werden soll, liegt in Challengr/Logic/ (ohne SwiftUI).
Neue Tests: Datei in ChallengrTests/ anlegen – Xcode nimmt sie automatisch auf.
Swift und Swift Kopie haben dieselben Tests (Ordner mitsynchronisieren).
