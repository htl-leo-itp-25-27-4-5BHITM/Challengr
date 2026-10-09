-- Demo-Spieler (nur Dev/Test). Stammdaten stehen in reference-data.sql.
-- Spieler
INSERT INTO player (id, name, longitude, latitude, points, trophies, consecutiveConflicts) VALUES
                                                                                 ('demo-1', 'EigenerSpieler', 14.251389, 48.268333, 800, 800, 0),
                                                                                 ('demo-2', 'ZweiterSpieler', 14.251400, 48.268300, 200, 200, 0),
                                                                                 ('3', 'WebappSpieler', 14.251385, 48.268639, 200, 200, 0);
