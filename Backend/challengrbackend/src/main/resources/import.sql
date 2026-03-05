-- Spieler
INSERT INTO player (name, longitude, latitude, points, consecutiveConflicts) VALUES
                                                                                 ('EigenerSpieler', 14.251389, 48.268333, 800, 0),
                                                                                 ('ZweiterSpieler', 14.251400, 48.268300, 200, 0),
                                                                                 ('WebappSpieler', 14.251385, 48.268639, 200, 0);

-- Kategorien (NEU: ohne Suchen, dafür iPhone & Customer)
INSERT INTO challenge_categories (name, description) VALUES
                                                         ('Fitness',  'Beweise deine Kraft und bleib in Bewegung!'),
                                                         ('Wissen',   'Teste dein Wissen über die Welt!'),
                                                         ('Mutprobe', 'Zeig Mut – verlasse deine Komfortzone!'),
                                                         ('iPhone',   'Nutze dein iPhone für kreative Challenges!'),
                                                         ('Customer', 'Von der Community erstellte Challenges.');

---------------------------------------------------------
-- FITNESS (klar messbar, kein Unentschieden)
---------------------------------------------------------
INSERT INTO challenges (text, category_id) VALUES
                                               ('Wer schafft in 60 Sekunden mehr Burpees?',
                                                (SELECT id FROM challenge_categories WHERE name = 'Fitness')),
                                               ('Wer hält länger einen Plank (Unterarmstütz)?',
                                                (SELECT id FROM challenge_categories WHERE name = 'Fitness')),
                                               ('Wer braucht weniger Zeit für 30 Kniebeugen?',
                                                (SELECT id FROM challenge_categories WHERE name = 'Fitness')),
                                               ('Wer springt in 30 Sekunden öfter Seil (auch unsichtbar)?',
                                                (SELECT id FROM challenge_categories WHERE name = 'Fitness')),
                                               ('Wer schafft mehr Liegestütze am Stück ohne Pause?',
                                                (SELECT id FROM challenge_categories WHERE name = 'Fitness'));

---------------------------------------------------------
-- MUTPROBE (klar: gemacht oder nicht)
---------------------------------------------------------
INSERT INTO challenges (text, category_id) VALUES
                                               ('Wer traut sich, eine fremde Person nach einem High-Five zu fragen?',
                                                (SELECT id FROM challenge_categories WHERE name = 'Mutprobe')),
                                               ('Wer traut sich, 10 Sekunden laut ein Lied in der Öffentlichkeit zu singen?',
                                                (SELECT id FROM challenge_categories WHERE name = 'Mutprobe')),
                                               ('Wer traut sich, 30 Sekunden in Superheld-Pose stehen zu bleiben?',
                                                (SELECT id FROM challenge_categories WHERE name = 'Mutprobe')),
                                               ('Wer traut sich, eine peinliche Story aus der Schulzeit zu erzählen?',
                                                (SELECT id FROM challenge_categories WHERE name = 'Mutprobe')),
                                               ('Wer traut sich, 1 Minute lang nur in Reimen zu sprechen?',
                                                (SELECT id FROM challenge_categories WHERE name = 'Mutprobe'));

---------------------------------------------------------
-- iPHONE (klar sichtbares Ergebnis)
---------------------------------------------------------
INSERT INTO challenges (text, category_id) VALUES
                                               ('Wer macht das kreativste Foto von einem zufälligen Gegenstand in der Nähe?',
                                                (SELECT id FROM challenge_categories WHERE name = 'iPhone')),
                                               ('Wer tippt eine kurze Nachricht an sich selbst schneller (Stoppuhr)?',
                                                (SELECT id FROM challenge_categories WHERE name = 'iPhone')),
                                               ('Wer findet in 30 Sekunden mehr blaue Apps auf seinem Homescreen?',
                                                (SELECT id FROM challenge_categories WHERE name = 'iPhone')),
                                               ('Wer macht das lustigste Selfie mit einem zufälligen Objekt im Hintergrund?',
                                                (SELECT id FROM challenge_categories WHERE name = 'iPhone')),
                                               ('Wer erstellt in 60 Sekunden die kreativste Notiz in seiner Notizen-App?',
                                                (SELECT id FROM challenge_categories WHERE name = 'iPhone'));

---------------------------------------------------------
-- WISSEN (Multiple Choice: option_a–d + correct_index)
-- Achtung: Tabelle braucht die Spalten option_a, option_b, option_c, option_d, correct_index
---------------------------------------------------------

INSERT INTO challenges (text, category_id, option_a, option_b, option_c, option_d, correct_index) VALUES
                                                                                                      (
                                                                                                          'Wie viele Planeten hat unser Sonnensystem?',
                                                                                                          (SELECT id FROM challenge_categories WHERE name = 'Wissen'),
                                                                                                          '7', '8', '9', '10',
                                                                                                          1  -- '8'
                                                                                                      ),
                                                                                                      (
                                                                                                          'Welches Element hat das chemische Symbol O?',
                                                                                                          (SELECT id FROM challenge_categories WHERE name = 'Wissen'),
                                                                                                          'Gold', 'Sauerstoff', 'Silber', 'Zinn',
                                                                                                          1  -- 'Sauerstoff'
                                                                                                      ),
                                                                                                      (
                                                                                                          'Welcher Kontinent ist flächenmäßig der größte?',
                                                                                                          (SELECT id FROM challenge_categories WHERE name = 'Wissen'),
                                                                                                          'Afrika', 'Asien', 'Europa', 'Südamerika',
                                                                                                          1  -- 'Asien'
                                                                                                      ),
                                                                                                      (
                                                                                                          'Wie viele Minuten hat eine Stunde?',
                                                                                                          (SELECT id FROM challenge_categories WHERE name = 'Wissen'),
                                                                                                          '30', '45', '60', '90',
                                                                                                          2  -- '60'
                                                                                                      ),
                                                                                                      (
                                                                                                          'Welches dieser Tiere ist ein Säugetier?',
                                                                                                          (SELECT id FROM challenge_categories WHERE name = 'Wissen'),
                                                                                                          'Hai', 'Frosch', 'Delfin', 'Goldfisch',
                                                                                                          2  -- 'Delfin'
                                                                                                      );

---------------------------------------------------------
-- RANKS (unverändert)
---------------------------------------------------------
INSERT INTO rank (name, min, max, color) VALUES
                                             ('Quittttter', 0, 99, 'gray'),
                                             ('Punchbag', 100, 199, 'red'),
                                             ('Scrapper', 200, 349, 'green'),
                                             ('Contender', 350, 599, 'yellow'),
                                             ('Tryhard', 600, 949, 'orange'),
                                             ('Brawler', 950, 1399, 'red'),
                                             ('Dueler', 1400, 1999, 'purple'),
                                             ('Challengr', 2000, 2800, 'yellow');
