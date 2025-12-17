-- Player Insert

INSERT INTO player (name, longitude, latitude) VALUES
                                                   ('EigenerSpieler', 14.251389, 48.268333),  -- ca. HTL Leonding Standort
                                                   ('ZweiterSpieler', 48.2683, 14.2514), -- ein Spieler in der Nähe von HTL Leonding
                                                    ('WebappSpieler', 14.251385, 48.268639);

-- Kategorien einfügen (IDs werden automatisch generiert)
INSERT INTO challenge_categories (name, description) VALUES
                                                         ('Fitness', 'Beweise deine Kraft und bleib in Bewegung!'),
                                                         ('Suchen', 'Entdecke spannende Dinge in deiner Umgebung.'),
                                                         ('Mutprobe', 'Zeig Mut – verlasse deine Komfortzone!'),
                                                         ('Wissen', 'Teste dein Wissen über die Welt!');

-- Fitness
INSERT INTO challenges (text, category_id) VALUES
                                               ('20 Liegestütze machen', (SELECT id FROM challenge_categories WHERE name='Fitness')),
                                               ('1 Minute Plank halten', (SELECT id FROM challenge_categories WHERE name='Fitness')),
                                               ('10 Kniebeugen mit Sprung', (SELECT id FROM challenge_categories WHERE name='Fitness')),
                                               ('30 Sekunden Hampelmänner', (SELECT id FROM challenge_categories WHERE name='Fitness')),
                                               ('5 Minuten zügig laufen oder joggen', (SELECT id FROM challenge_categories WHERE name='Fitness'));

-- Suchen
INSERT INTO challenges (text, category_id) VALUES
                                               ('Fotografiere Hausnummer 5', (SELECT id FROM challenge_categories WHERE name='Suchen')),
                                               ('Finde und fotografiere 3 rote Autos', (SELECT id FROM challenge_categories WHERE name='Suchen')),
                                               ('Mache ein Foto von einem Stoppschild', (SELECT id FROM challenge_categories WHERE name='Suchen')),
                                               ('Finde ein Tier und mache ein Foto davon', (SELECT id FROM challenge_categories WHERE name='Suchen')),
                                               ('Fotografiere etwas, das die Farbe Gelb hat', (SELECT id FROM challenge_categories WHERE name='Suchen'));

-- Mutprobe
INSERT INTO challenges (text, category_id) VALUES
                                               ('Singe laut ein Lied in der Öffentlichkeit', (SELECT id FROM challenge_categories WHERE name='Mutprobe')),
                                               ('Frage eine fremde Person nach einem High-Five', (SELECT id FROM challenge_categories WHERE name='Mutprobe')),
                                               ('Dusche 30 Sekunden eiskalt', (SELECT id FROM challenge_categories WHERE name='Mutprobe')),
                                               ('Rufe jemanden an und sage ihm, dass du ihn magst', (SELECT id FROM challenge_categories WHERE name='Mutprobe')),
                                               ('Iss etwas Ungewöhnliches (z. B. Zitrone pur)', (SELECT id FROM challenge_categories WHERE name='Mutprobe'));

-- Wissen
INSERT INTO challenges (text, category_id) VALUES
                                               ('Wie viele Kontinente gibt es auf der Erde?', (SELECT id FROM challenge_categories WHERE name='Wissen')),
                                               ('Was ist die Hauptstadt von Kanada?', (SELECT id FROM challenge_categories WHERE name='Wissen')),
                                               ('Welches chemische Symbol steht für Gold?', (SELECT id FROM challenge_categories WHERE name='Wissen')),
                                               ('Nenne drei Planeten unseres Sonnensystems', (SELECT id FROM challenge_categories WHERE name='Wissen')),
                                               ('Welches Jahr gilt als Beginn des Internetzeitalters?', (SELECT id FROM challenge_categories WHERE name='Wissen'));
