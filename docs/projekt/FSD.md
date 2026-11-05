# Functional Specification Document

**Project:** Challengr
**Class / Year:** 4BHITM / 5BHITM, 2025/26 – 2026/27
**Document status:** Draft for review
**Last updated:** 2026-09-28

---

## 1. Project Overview

### Project title

**Challengr** – location-based real-life challenges between players nearby

### Short description

Challengr is an iOS app in which players who are physically close to each other can challenge one another to short real-life duels ("battles"). A player sees other players within a small radius on a map, picks one, and sends a randomly selected challenge from a category (e.g. fitness, dare, knowledge, or a phone-sensor challenge). If the opponent accepts, both play the challenge in real time; the result is determined either by the app (sensor measurements, quiz answers) or by both players voting. Winners gain points, climb ranks, and can spend points in an in-app shop. A web-based admin dashboard lets the team manage challenges and players.

### Background / current situation

- Social media platforms offer "challenges", but they are not location-based, have no clear rules, no fair result mechanism and no direct player-versus-player competition.
- Existing fitness and game apps are either purely digital or focus on individual performance rather than spontaneous meetings with people nearby.
- There is currently no app that lets people meet spontaneously in real life, compete against each other in small tasks, and see their progress in a ranking system.

### Problem statement

- **Main problem:** People who want to compete with others in short, fun real-life tasks have no tool that finds opponents nearby, provides fair challenges, and records results.
- **Sub-problems:**
  - Finding opponents in the immediate surroundings is not possible without prior contact.
  - Without shared rules, results are disputed ("Who actually won?").
  - Without a points and rank system, there is little long-term motivation to take part again.
  - Outdoor activity and social contact are not rewarded in typical mobile games.

### Project goals

- Players can see other players within a defined radius on a map in real time.
- Players can challenge each other to a battle and play it immediately.
- Results are determined fairly: automatically where possible (sensors, quiz), otherwise by both players voting.
- A points system with ranks, a daily streak and badges motivates players to return.
- Players can add friends and send them gifts.
- Players can spend points in a shop.
- Administrators can manage challenges and players through a web dashboard.
- The system runs in the school's cloud environment (LeoCloud) and can be tested by students in school tests.

---

## 2. Scope

### In Scope

- **iOS app (Swift / SwiftUI)**
  - Login via the school's identity provider (Keycloak)
  - Onboarding and character (avatar) selection
  - Map with own position, radius, and nearby players
  - Sending, receiving, accepting, declining and cancelling challenges
  - Battle types: normal battle with voting, knowledge quiz, and iPhone sensor challenges (sprint, check-in spot, compass, shake, loudness, camera, push-ups)
  - Result screens (win / lose) with points and comparison values
  - Profile with points, rank, daily streak, statistics, battle history and badges
  - Trophy road (rank progression)
  - Friends: add via QR code or AirDrop invite, friend requests, friend list, gifts
  - Shop with items that can be bought with points
  - Sound effects and settings (sound on/off, notifications on/off, logout)
  - Local notifications while the app is in the background for a short time
- **Backend (Quarkus / Java, PostgreSQL)**
  - REST API for players, challenges, categories, ranks, friends, shop, and admin functions
  - WebSocket connection for real-time battle communication
  - Evaluation of battles, points calculation, conflict penalties
  - Automatic expiry of unanswered requests and cancellation of stuck battles
- **Admin dashboard (Angular web app)**
  - Overview with key figures
  - User search, filter, ban and unban
  - Challenge management (list and create challenges)
  - Database overview (ERD and table data)
- **Operations**
  - Deployment to LeoCloud (Kubernetes) with Docker images
  - Automated tests for backend and iOS app

### Out of Scope

- Android app (only a roadmap document exists)
- Remote push notifications when the app is fully closed (requires a paid Apple Developer account and an APNs key)
- Real-money payments or in-app purchases with money
- Effects of shop items in battles (items can be bought and owned, but have no gameplay effect yet)
- Public release in the Apple App Store
- Chat or messaging between players
- Global leaderboard screen in the app
- Challenge difficulty levels (easy / medium / hard), which were mentioned in the original proposal
- The former web app for players (only used for early testing, no longer maintained)

---

## 3. Users and Stakeholders

### Primary users

- **Players:** young people and young adults (approx. 14–30 years), e.g. students, gamers, fitness- and outdoor-oriented people, groups of friends who want to compete against each other.

### Secondary users

- **Administrators:** members of the project team who manage challenges, monitor the system and ban players who misbehave (via the admin dashboard).
- **Testers:** students and teachers taking part in school tests.

### Stakeholders

- **Clients / supervisors:** Dietmar Steiner, Christian Aberger, Dejan Sivak
- **Project team:** Julian Richter (Swift, backend), Dominik Binder (Swift, design), Björn Wanson (design, backend), Sebastian Lehner (design, backend)
- **School (HTL Leonding):** provides the LeoCloud infrastructure and the Keycloak login
- **Test participants at school:** underage users, which makes data protection a relevant concern

---

## 4. Use Cases / User Scenarios

### UC-01: Challenge a player nearby (normal battle)

1. Player A opens the app and sees the map with their own position and a 200 m radius.
2. Player B appears as a pin on the map.
3. Player A taps on Player B, chooses a category (e.g. "Fitness") and gets a random challenge.
4. Player A presses "Senden". Player A sees "Anfrage gesendet – Warte auf Annahme".
5. Player B receives a popup with the challenge and accepts it.
6. Both see the battle screen and perform the task in real life.
7. After the task, both vote on who won.
8. If both vote for the same person, the winner gets points and the loser loses points. Both see the result screen.

### UC-02: Sensor challenge (e.g. sprint)

1. Player A challenges Player B with an iPhone challenge ("Sprint-Challenge").
2. After accepting, both see a countdown and then run as far as possible for 15 seconds.
3. Each app measures the distance and sends it to the server.
4. The first player to finish sees "Ergebnis wird berechnet…" until the second value arrives (at most 45 seconds).
5. The server compares the values, the player with the longer distance wins, and both see the result including the measured distances.

### UC-03: Knowledge quiz

1. Player A challenges Player B with a "Wissen" challenge.
2. After accepting, both receive the same multiple-choice question with four answers.
3. The first player to select the correct answer wins immediately. Wrong answers do not end the battle.

### UC-04: Add a friend and send a gift

1. Player A shows their QR code or shares an invite via AirDrop.
2. Player B scans the code or opens the invite file and sends a friend request.
3. Player A sees a banner on the map and a badge on the profile button and accepts the request.
4. Both appear in each other's friend list. Player A sends Player B a gift, which Player B can open.

### UC-05: Administrator manages challenges and players

1. An administrator opens the dashboard in the browser.
2. They create a new challenge (e.g. a new knowledge question with four answers and the correct answer).
3. They search for a player who behaved inappropriately and ban them for a set time with a reason.

---

## 5. Functional Requirements

Priority: **MUST** = required for the first complete version, **SHOULD** = important, **COULD** = optional.

### Account and profile

- **FR-01 (MUST):** The app shall require the user to log in via Keycloak before any game function is available.
- **FR-02 (MUST):** The system shall link every Keycloak user to exactly one player record, using the Keycloak user ID as player ID, and shall not create duplicates.
- **FR-03 (MUST):** The app shall allow the user to log out from the settings screen.
- **FR-04 (SHOULD):** The app shall let new users choose a character (avatar) during onboarding and change it later in the profile.
- **FR-05 (MUST):** The profile shall show the player's name, avatar, points, rank, daily streak, number of battles, number of wins, a points history and a battle history.
- **FR-06 (SHOULD):** The system shall award badges for milestones: first win, 3 wins, 5 battles, and a win streak of 3.
- **FR-07 (SHOULD):** The app shall show a trophy road with all ranks and the player's current position.

### Map and location

- **FR-08 (MUST):** The app shall show the player's own position on a map together with a visible radius of 200 m.
- **FR-09 (MUST):** The app shall show other players within the radius as pins, colored by their rank.
- **FR-10 (MUST):** The app shall send the player's position to the backend regularly while the app is open.
- **FR-11 (MUST):** The nearby-player list shall update within a few seconds when a player moves (real-time update via WebSocket, with polling as fallback).
- **FR-12 (MUST):** The backend shall only notify players within 300 m about another player's movement and shall not include coordinates in this notification.

### Challenges and requests

- **FR-13 (MUST):** The system shall provide challenges in five categories: Fitness, Mutprobe (dare), Wissen (knowledge), iPhone (sensor challenges), and Customer (community-created).
- **FR-14 (MUST):** When challenging a player, the app shall let the user choose a category and then select a random challenge from that category.
- **FR-15 (MUST):** The system shall send the challenge request to the opponent in real time, including the challenge text and category.
- **FR-16 (MUST):** The opponent shall be able to accept or decline a request.
- **FR-17 (MUST):** The challenger shall see a waiting screen and be able to cancel the request. After cancelling, the opponent's popup shall disappear and the request can no longer be accepted.
- **FR-18 (MUST):** An unanswered request shall expire after 60 seconds. Both players shall be informed.
- **FR-19 (MUST):** A request that arrives while the opponent is briefly offline shall be delivered again when the opponent reconnects, as long as it has not expired.
- **FR-20 (MUST):** The system shall reject a request if a player challenges themselves, challenges in someone else's name, or already has an open request with the same opponent. The challenger shall see the reason.

### Battles and results

- **FR-21 (MUST):** For normal challenges, the app shall show a battle screen with a timer and a surrender option. Afterwards, both players shall vote for the winner.
- **FR-22 (MUST):** Each player shall have exactly one vote per battle. If both votes agree, that player wins. If they disagree, the battle ends as a conflict.
- **FR-23 (MUST):** For knowledge challenges, both players shall receive the same question with four answers. The first correct answer wins. The correct answer shall not be sent to the app.
- **FR-24 (MUST):** For iPhone challenges, the app shall open the matching special view:
  - Sprint: longest distance in 15 seconds wins
  - Check-in spot: first player to reach a random target point within 500 m wins
  - Compass: smallest deviation from a random target direction wins
  - Shake: most shakes in 10 seconds wins
  - Loudness: loudest value in 10 seconds wins
  - Camera: best match with a given color wins
  - Push-ups: most repetitions in 30 seconds (counted via face detection) wins
- **FR-25 (MUST):** For measured challenges, the server shall evaluate the battle only when both values have arrived, or at the latest 45 seconds after the first value. A missing value counts as the worst possible result.
- **FR-26 (MUST):** If a player surrenders, the opponent shall win.
- **FR-27 (MUST):** A battle shall be evaluated exactly once. Points shall never be awarded twice for the same battle.
- **FR-28 (MUST):** The result shall only be sent to the two players of the battle. The app shall ignore results of battles it is not part of.
- **FR-29 (MUST):** The app shall show a win or lose screen with both players, the point changes, and (for measured challenges) the measured values of both players.
- **FR-30 (MUST):** A battle that has been accepted but shows no progress for 10 minutes shall be cancelled automatically without points. Both players shall be informed.

### Points and ranks

- **FR-31 (MUST):** New players shall start with 200 points.
- **FR-32 (MUST):** The winner of a battle shall receive points and the loser shall lose points. The amount depends on the rank difference (see section 8).
- **FR-33 (MUST):** The player's rank shall be derived from their points (see section 8).
- **FR-34 (MUST):** After three conflicts in a row, both players shall receive a point penalty that increases with every further conflict. A regular result resets the conflict counter.
- **FR-35 (SHOULD):** The profile shall show the daily streak (number of consecutive days, up to today, with at least one finished battle).

### Friends and gifts

- **FR-36 (SHOULD):** A player shall be able to show their own invite as a QR code and share it as a file via AirDrop.
- **FR-37 (SHOULD):** A player shall be able to scan a QR code or open an invite file to send a friend request.
- **FR-38 (SHOULD):** The recipient shall see a banner on the map and a counter on the profile button for new friend requests, and shall be able to accept or decline them.
- **FR-39 (SHOULD):** The sender shall be informed when their friend request is accepted.
- **FR-40 (SHOULD):** Players shall be able to remove friends.
- **FR-41 (COULD):** Players shall be able to send a gift to a friend. The friend shall be able to open (claim) the gift once.

### Shop

- **FR-42 (SHOULD):** The app shall show a shop with items (name, image, price, rarity) and the player's current points.
- **FR-43 (SHOULD):** A player shall be able to buy an item if they have enough points. The points shall be deducted and the owned quantity increased.
- **FR-44 (SHOULD):** A purchase with insufficient points shall be rejected with a message.

### Sound and notifications

- **FR-45 (SHOULD):** The app shall play sound effects for key events (challenge sent/received/accepted/declined, battle start, countdown, win, lose, purchase, gifts, friend requests).
- **FR-46 (SHOULD):** The user shall be able to switch sound effects off in the settings.
- **FR-47 (COULD):** While the app is in the background (up to approx. 30 seconds after leaving it), the app shall show a local notification for new challenges and friend requests. The user shall be able to switch notifications off.

### Admin dashboard

- **FR-48 (MUST):** The dashboard shall show an overview with key figures (e.g. active/total players, active bans, finished battles, most-played category).
- **FR-49 (SHOULD):** The dashboard shall allow searching and filtering players.
- **FR-50 (MUST):** An administrator shall be able to ban a player for a period with a reason and lift a ban. Banned players shall not be able to log in.
- **FR-51 (MUST):** An administrator shall be able to list all challenges and create new ones. Knowledge challenges require exactly four answers and the index of the correct answer.
- **FR-52 (COULD):** The dashboard shall show the database structure (ERD) and table contents for debugging.

---

## 6. Non-Functional Requirements

### Usability

- The user interface shall be in German; proper names (e.g. rank names, "Challengr") may stay in English.
- Challenging a player shall take at most three taps after the player is visible on the map (tap player → choose category → send).
- Every important state (waiting, accepted, declined, expired, result pending) shall be visible to the user with a clear message or banner.
- The design shall follow the Challengr style (dark red / yellow color scheme, rounded "game" cards and buttons).

### Performance

- Challenge requests, status changes and results shall reach the other player in under 2 seconds under normal network conditions.
- The nearby-player list shall refresh at least every 4 seconds while the map is open, and faster when a movement event arrives.
- The backend shall handle at least the number of players in a school test (approx. 30–50 simultaneous users) without noticeable delays.

### Reliability

- The WebSocket connection shall reconnect automatically after network interruptions.
- Messages sent while the connection is down shall be queued and sent after reconnecting.
- No battle may remain in a waiting state forever (request timeout 60 s, result timeout 45 s, battle timeout 10 min).
- Points shall remain consistent even if messages arrive twice or at the same time.

### Maintainability

- Backend logic shall be covered by automated tests (unit tests and WebSocket end-to-end tests with an in-memory database).
- Testable app logic (e.g. choosing the battle view, result evaluation) shall be kept separate from the UI and covered by unit tests.
- Deployment shall run the backend tests first and stop if one fails.
- Code comments and documentation may be written in German or English.

### Constraints

- The app runs on iOS 17.6 or later (iPhone). There is no Android version.
- The backend runs on Quarkus (Java 21) with PostgreSQL on the school's LeoCloud (Kubernetes).
- Login uses the school's Keycloak instance.
- Location, camera and microphone access are required for the full feature set.
- Development is limited to the school years and sprint rhythm (two-week sprints).
- Because test users are minors, personal data (especially exact location) must be shared as little as possible.

---

## 7. Data and Content

### Inputs

- Login data (via Keycloak, not stored by the app)
- Player position (latitude / longitude)
- Selected category and opponent when challenging
- Accept, decline, cancel and surrender actions
- Votes (winner ID), quiz answers (answer index)
- Sensor values: distance (m), loudness (dB), compass deviation (°), shakes (count), camera score, push-up repetitions
- Friend invites (QR code / invite file), friend request actions, gifts
- Shop purchases
- Settings (sound, notifications, avatar)
- Admin input: new challenges, bans with reason and duration

### Outputs

- Map with nearby players and their rank color
- Challenge popups, waiting screens, banners
- Battle screens, quiz questions, countdowns
- Win / lose screens with point changes and measured values
- Profile, statistics, battle history, badges, trophy road
- Friend list, friend requests, gifts
- Shop with items and remaining points
- Dashboard key figures, player lists, challenge lists, ERD

### Stored data

- **Player:** ID (Keycloak ID), name, position, points, consecutive conflicts, profile status, badges, best loudness, ban end and reason
- **Challenge:** ID, text, category, for knowledge challenges four answer options and the index of the correct answer
- **Challenge category:** name, description
- **Battle:** ID, challenger, opponent, challenge, category, status, winner, point changes, target point (check-in spot), creation time, time of last status change
- **Rank:** name, min and max points, color
- **Friend request / friendship / gift:** sender, recipient, status, timestamps
- **Shop item / owned items:** code, name, image, price, rarity, quantity per player
- **On the device only:** settings (sound, notifications) and selected avatar

### Data rules

- Player IDs are the Keycloak user IDs.
- Points may change only through battle results, conflict penalties and shop purchases, never directly through the position update.
- Battle status values: REQUESTED, ACCEPTED, DECLINED, CANCELLED, EXPIRED, READY_FOR_VOTING, CHECKIN_DONE, DONE_SURRENDER, DONE, ABANDONED. DONE, EXPIRED, CANCELLED, DECLINED and ABANDONED are final.
- The correct answer of a knowledge challenge is only visible in the admin dashboard.
- Exact positions of other players are only provided for players within the map radius.

---

## 8. Business Rules / Logic

### Validation rules

- A challenge must have a text and an existing category.
- A knowledge challenge must have exactly four answers and a correct index between 0 and 3.
- A player cannot challenge themselves.
- Only one open request is allowed per pair of players (in either direction).
- A player can only send requests in their own name.
- A shop purchase requires enough points.

### Permissions

- **Players:** can only act on battles they are part of (accept, decline, vote, answer, send results).
  - Only the opponent can accept or decline.
  - Only the challenger can cancel.
  - Players outside a battle cannot vote or send results for it.
- **Administrators:** can use the dashboard (manage challenges, ban/unban players, view data).
- **Banned players:** cannot log in until the ban ends.

### Process rules

- **Request lifecycle:** REQUESTED → ACCEPTED / DECLINED / CANCELLED / EXPIRED (after 60 s).
- **Battle lifecycle:** ACCEPTED → (READY_FOR_VOTING / CHECKIN_DONE / DONE_SURRENDER) → DONE; or ABANDONED after 10 minutes without progress.
- **Result determination:**
  - Voting: both votes equal → that player wins; different → conflict.
  - Knowledge: first correct answer wins.
  - Check-in spot: first player to check in wins.
  - Measured challenges: better value wins; equal values → draw (no points). For push-ups, equal values count as a conflict.
  - Surrender: the other player wins.
- **Points calculation (current implementation):**
  - Base values: winner +30, loser −20.
  - For each rank of difference, the values change by 5 %: a lower-ranked winner gains more and the higher-ranked loser loses more; a higher-ranked winner gains less and the lower-ranked loser loses less.
- **Conflict penalty:** conflict counter +1 for both players. From the 3rd consecutive conflict: −10 points, 4th: −20, and so on. A regular result resets the counter.
- **Ranks:**

  | Rank | Points |
  |---|---|
  | Quitter | 0–99 |
  | Punchbag | 100–199 |
  | Scrapper | 200–349 |
  | Contender | 350–599 |
  | Tryhard | 600–949 |
  | Brawler | 950–1399 |
  | Dueler | 1400–1999 |
  | Challengr | 2000+ |

- **Daily streak:** number of consecutive days up to today with at least one finished battle.

---

## 9. Error Handling / Edge Cases

### Invalid input

- Invalid or incomplete WebSocket messages are answered with an error message and do not crash the server.
- Invalid challenge data in the dashboard (missing text, unknown category, wrong number of answers) is rejected with HTTP 400.
- A purchase without enough points shows "Nicht genug Punkte".

### Missing data

- If the challenge text is missing in a request, the app looks it up in its local list and otherwise loads it from the server. It never shows a different challenge.
- If no challenge exists in a category, the category button is disabled.
- If the check-in spot has no target point (challenger's position unknown), a normal battle is played instead.
- If one player never sends a measured value, the battle is evaluated after 45 seconds and that player loses.

### Exceptional situations

- **Opponent offline:** the request is delivered when they reconnect or expires after 60 seconds.
- **Request cancelled or expired while the popup is open:** the popup closes with a banner, and accepting is no longer possible.
- **Player closes the app during a battle:** the battle is cancelled after 10 minutes without points.
- **Both players surrender or vote at the same time / double taps:** only the first evaluation counts; points are awarded once.
- **Two players with the same name:** results and votes use player IDs, so the correct player is identified.
- **Connection loss:** automatic reconnect, and queued messages are sent afterwards.
- **App in background:** a local notification is shown for about 30 seconds. After that, iOS closes the connection and new requests arrive only after reopening (as long as they have not expired).
- **Permission denied (location, camera, microphone):** the related features cannot be used, and the rest of the app keeps working.

---

## 10. Assumptions and Dependencies

### Technical assumptions

- Players use an iPhone with iOS 17.6 or later, with GPS, camera, microphone and motion sensors.
- Players have mobile internet during battles.
- The GPS accuracy is sufficient for a 200 m radius and a 30 m check-in radius.
- The number of simultaneous users stays at school-test scale.

### Organizational assumptions

- The school provides LeoCloud and Keycloak for the whole project duration.
- School tests are carried out with the consent of the school and the participants.
- The project team has access to at least two iPhones for testing (therefore two app variants with different bundle IDs exist).

### Dependencies

- **Keycloak** (authentication)
- **PostgreSQL** (data storage)
- **LeoCloud / Kubernetes and GitHub Container Registry** (deployment)
- **Apple frameworks:** MapKit, CoreLocation, AVFoundation, Vision / camera, CoreMotion, UserNotifications
- **Quarkus extensions:** REST, WebSockets, Hibernate ORM with Panache, OIDC, Scheduler
- **Angular** (admin dashboard)

---

## 11. Acceptance Criteria

- **AC-01:** A user can log in with a school account and sees the map with their own position and a 200 m radius.
- **AC-02:** Two logged-in players within 200 m see each other on the map within 5 seconds.
- **AC-03:** Player A can challenge Player B. Player B receives the popup with the same challenge text that Player A saw, within 2 seconds.
- **AC-04:** If Player A cancels, the popup on Player B's device disappears and the request cannot be accepted anymore.
- **AC-05:** An unanswered request expires after 60 seconds, and both players see a message.
- **AC-06:** In a normal battle where both players vote for the same player, that player wins, and the point changes shown on the result screen are stored in the database.
- **AC-07:** In a sprint challenge, the player with the longer distance wins regardless of who sent their result first, and both measured distances are shown.
- **AC-08:** In a knowledge battle, the first correct answer wins, and the correct answer is not visible in the network traffic of the app.
- **AC-09:** A third player who is connected but not part of the battle does not receive the result and does not see a result screen.
- **AC-10:** Double taps or simultaneous surrender by both players lead to exactly one result and a single point change.
- **AC-11:** A player cannot challenge themselves or send a second request to the same opponent while one is open, and they see the reason.
- **AC-12:** All seven iPhone challenges open their dedicated view.
- **AC-13:** A friend request sent via QR code appears on the recipient's map as a banner, and after acceptance both players appear in each other's friend list.
- **AC-14:** A player with enough points can buy a shop item. The points decrease and the item quantity increases.
- **AC-15:** An administrator can create a knowledge challenge in the dashboard, and it can be played in the app afterwards.
- **AC-16:** A banned player cannot log in until the ban ends.
- **AC-17:** Switching off sound effects in the settings mutes all effects.
- **AC-18:** All automated tests (backend and iOS) pass, and deployment is blocked if a backend test fails.

---

## 12. Open Questions

1. **Radius:** The original proposal specifies 50 m, but the app currently uses 200 m for the map and nearby players. Which value is final?
2. **Points:** The ranking document specifies +28 to +33 points for a win and a fixed −25 for a loss, but the implementation uses +30 / −20 with a 5 % rank adjustment. Which rule applies?
3. **Shop items:** What effect should the items (e.g. Streak Saver, Point Shield, Rematch Ticket, Stealth Cloak) have in the game? Currently they can only be bought.
4. **Gifts:** What does a gift contain (e.g. points or an item)? Currently it can only be sent and opened.
5. **Push notifications:** Will a paid Apple Developer account be available so that real push notifications (with the app closed) can be implemented?
6. **Draws:** Should a draw be shown differently from a loss? Currently both players see the lose screen with "Unentschieden!".
7. **Data persistence:** The production database is currently recreated on every deployment (drop-and-create). When will this be switched to schema update, so that points and friends are kept?
8. **Admin protection:** The challenge list with correct answers and the admin endpoints are not yet protected by an admin role. When will role-based access be implemented?
9. **WebSocket authentication:** The WebSocket connection is currently identified only by the player ID. Will the Keycloak token be verified there as well?
10. **Challenge types:** The app recognizes special iPhone challenges by keywords in the challenge text. Should a dedicated "type" field be introduced so that renaming a challenge cannot break it?
11. **Challenge texts:** The camera challenge text mentions "a red car", but the app asks for a random color. The shake challenge text says 5 seconds, but the app measures 10 seconds. Which one should be adjusted?
12. **Cheating:** Sensor values are measured on the device and trusted by the server. Are plausibility limits (e.g. maximum sprint distance) required?
13. **Difficulty levels:** The proposal mentions easy / medium / hard challenges. Are they still planned?
