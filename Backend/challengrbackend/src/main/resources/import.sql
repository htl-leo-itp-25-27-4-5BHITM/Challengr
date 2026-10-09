-- Spieler
INSERT INTO player (id, name, longitude, latitude, points, knowledgeTrophies, realLifeTrophies, consecutiveConflicts) VALUES
                                                                                 ('demo-1', 'EigenerSpieler', 14.251389, 48.268333, 800, 800, 800, 0),
                                                                                 ('demo-2', 'ZweiterSpieler', 14.251400, 48.268300, 200, 200, 200, 0),
                                                                                 ('3', 'WebappSpieler', 14.251385, 48.268639, 200, 200, 200, 0);

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
-- Zusätzliche iPhone-Challenges mit Sensorspielereien
INSERT INTO challenges (text, category_id) VALUES
                                               (
                                                   'Sprint-Challenge: Laufe in 15 Sekunden so weit wie möglich.',
                                                   (SELECT id FROM challenge_categories WHERE name = 'iPhone')
                                               ),
                                               (
                                                   'Check-In-Spot: Erreiche den Zielpunkt auf der Karte.',
                                                   (SELECT id FROM challenge_categories WHERE name = 'iPhone')
                                               ),
                                               (
                                                   'Kompass-Präzision: Richte dich auf einen zufälligen Zielwinkel aus.',
                                                   (SELECT id FROM challenge_categories WHERE name = 'iPhone')
                                               ),
                                               (
                                                   'Shake-Challenge: Schüttle das iPhone 5 Sekunden lang maximal.',
                                                   (SELECT id FROM challenge_categories WHERE name = 'iPhone')
                                               ),
                                               (
                                                   'Schrei-Challenge: Sei in 10 Sekunden so laut wie möglich.',
                                                   (SELECT id FROM challenge_categories WHERE name = 'iPhone')
                                               ),
                                               (
                                                   'Foto-Beweis: Finde ein rotes Auto und fotografiere es.',
                                                   (SELECT id FROM challenge_categories WHERE name = 'iPhone')
                                               ),
                                               (
                                                   'Liegestütz-Zähler: Zähle deine Push-Ups mit der Nase auf dem Screen.',
                                                   (SELECT id FROM challenge_categories WHERE name = 'iPhone')
                                               );
--------------------------------------------------
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
                                             ('Quitter', 0, 99, 'gray'),
                                             ('Punchbag', 100, 199, 'red'),
                                             ('Scrapper', 200, 349, 'green'),
                                             ('Contender', 350, 599, 'yellow'),
                                             ('Tryhard', 600, 949, 'orange'),
                                             ('Brawler', 950, 1399, 'red'),
                                             ('Dueler', 1400, 1999, 'purple'),
                                             ('Challengr', 2000, 2800, 'yellow');

---------------------------------------------------------
-- WISSEN: zusätzliche Fragen für die Quiz-Show (Liga Wissen, 4 Fragen pro Battle)
---------------------------------------------------------
INSERT INTO challenges (text, category_id, option_a, option_b, option_c, option_d, correct_index) VALUES
    ('Was ist die Hauptstadt von Österreich?', (SELECT id FROM challenge_categories WHERE name = 'Wissen'), 'Graz', 'Wien', 'Linz', 'Salzburg', 1),
    ('Wie viele Bundesländer hat Österreich?', (SELECT id FROM challenge_categories WHERE name = 'Wissen'), '7', '8', '9', '10', 2),
    ('Welcher ist der höchste Berg Österreichs?', (SELECT id FROM challenge_categories WHERE name = 'Wissen'), 'Großglockner', 'Dachstein', 'Wildspitze', 'Zugspitze', 0),
    ('Welcher Fluss fließt durch Linz?', (SELECT id FROM challenge_categories WHERE name = 'Wissen'), 'Inn', 'Donau', 'Mur', 'Enns', 1),
    ('Wie viele Seiten hat ein Sechseck?', (SELECT id FROM challenge_categories WHERE name = 'Wissen'), '5', '6', '7', '8', 1),
    ('Was ist 7 × 8?', (SELECT id FROM challenge_categories WHERE name = 'Wissen'), '54', '56', '58', '64', 1),
    ('Welcher Planet ist der Sonne am nächsten?', (SELECT id FROM challenge_categories WHERE name = 'Wissen'), 'Venus', 'Mars', 'Merkur', 'Erde', 2),
    ('Wie lautet die chemische Formel von Wasser?', (SELECT id FROM challenge_categories WHERE name = 'Wissen'), 'CO2', 'H2O', 'O2', 'NaCl', 1),
    ('In welchem Jahr fiel die Berliner Mauer?', (SELECT id FROM challenge_categories WHERE name = 'Wissen'), '1985', '1989', '1991', '1995', 1),
    ('Wer malte die Mona Lisa?', (SELECT id FROM challenge_categories WHERE name = 'Wissen'), 'Michelangelo', 'Van Gogh', 'Leonardo da Vinci', 'Picasso', 2),
    ('Wie viele Kontinente gibt es?', (SELECT id FROM challenge_categories WHERE name = 'Wissen'), '5', '6', '7', '8', 2),
    ('Wofür steht HTML?', (SELECT id FROM challenge_categories WHERE name = 'Wissen'), 'HyperText Markup Language', 'High Tech Modern Language', 'Home Tool Markup Language', 'Hyper Transfer Main Link', 0),
    ('Wie viele Bits hat ein Byte?', (SELECT id FROM challenge_categories WHERE name = 'Wissen'), '4', '8', '16', '32', 1),
    ('Welche Programmiersprache läuft direkt im Webbrowser?', (SELECT id FROM challenge_categories WHERE name = 'Wissen'), 'Swift', 'Java', 'JavaScript', 'C', 2),
    ('Welches ist das größte Tier der Welt?', (SELECT id FROM challenge_categories WHERE name = 'Wissen'), 'Afrikanischer Elefant', 'Blauwal', 'Giraffe', 'Weißer Hai', 1),
    ('Wie viele Spieler einer Fußballmannschaft stehen auf dem Feld?', (SELECT id FROM challenge_categories WHERE name = 'Wissen'), '9', '10', '11', '12', 2),
    ('Welches Organ pumpt das Blut durch den Körper?', (SELECT id FROM challenge_categories WHERE name = 'Wissen'), 'Lunge', 'Leber', 'Herz', 'Niere', 2),
    ('Was ist die Hauptstadt von Frankreich?', (SELECT id FROM challenge_categories WHERE name = 'Wissen'), 'Lyon', 'Paris', 'Marseille', 'Nizza', 1),
    ('Welcher Komponist wurde in Salzburg geboren?', (SELECT id FROM challenge_categories WHERE name = 'Wissen'), 'Beethoven', 'Mozart', 'Bach', 'Haydn', 1),
    ('Wie heißt der längste Fluss Europas?', (SELECT id FROM challenge_categories WHERE name = 'Wissen'), 'Donau', 'Rhein', 'Wolga', 'Elbe', 2),
    ('Was ist die Wurzel aus 144?', (SELECT id FROM challenge_categories WHERE name = 'Wissen'), '10', '11', '12', '14', 2),
    ('Welche Farbe entsteht aus Blau und Gelb?', (SELECT id FROM challenge_categories WHERE name = 'Wissen'), 'Grün', 'Orange', 'Lila', 'Braun', 0),
    ('Wie viele Tage hat ein Schaltjahr?', (SELECT id FROM challenge_categories WHERE name = 'Wissen'), '364', '365', '366', '367', 2),
    ('Welches Gas nehmen Pflanzen bei der Photosynthese auf?', (SELECT id FROM challenge_categories WHERE name = 'Wissen'), 'Sauerstoff', 'Stickstoff', 'Kohlendioxid', 'Helium', 2),
    ('In welcher Stadt steht der Stephansdom?', (SELECT id FROM challenge_categories WHERE name = 'Wissen'), 'Graz', 'Wien', 'Innsbruck', 'Linz', 1),
    ('Welcher Ozean ist der größte?', (SELECT id FROM challenge_categories WHERE name = 'Wissen'), 'Atlantik', 'Indischer Ozean', 'Pazifik', 'Arktischer Ozean', 2),
    ('Was misst man in Hertz?', (SELECT id FROM challenge_categories WHERE name = 'Wissen'), 'Frequenz', 'Stromstärke', 'Temperatur', 'Druck', 0),
    ('Wer entwickelte die Relativitätstheorie?', (SELECT id FROM challenge_categories WHERE name = 'Wissen'), 'Newton', 'Einstein', 'Tesla', 'Curie', 1),
    ('Wie viele Ecken hat ein Würfel?', (SELECT id FROM challenge_categories WHERE name = 'Wissen'), '6', '8', '10', '12', 1),
    ('Welches Land hat die meisten Einwohner?', (SELECT id FROM challenge_categories WHERE name = 'Wissen'), 'China', 'Indien', 'USA', 'Indonesien', 1);

---------------------------------------------------------
-- SHOP ITEMS
---------------------------------------------------------
INSERT INTO shop_item (code, name, imageName, price, rarity) VALUES
                                             ('coin', 'Coin', 'Coin 1', 50, 'common'),
                                             ('trophy', 'Trophy', 'Trophy 1', 100, 'common'),
                                             ('combo_booster', 'Combo Booster', 'ComboBooster 1', 150, 'uncommon'),
                                             ('trophy_boost', 'Trophy Boost', 'Energieflasche 1', 200, 'uncommon'),
                                             ('rematch_ticket', 'Rematch Ticket', 'RematchTicket 1', 250, 'rare'),
                                             ('stealth_cloak', 'Stealth Cloak', 'StealthCloak 1', 300, 'rare'),
                                             ('streak_saver', 'Streak Saver', 'StreakSaver 1', 400, 'epic'),
                                             ('point_shield', 'Point Shield', 'PunkteSchild 1', 600, 'epic'),
                                             ('full_stealth_potion', 'Full Stealth Potion', 'Unsichtbar 1', 800, 'legendary');


