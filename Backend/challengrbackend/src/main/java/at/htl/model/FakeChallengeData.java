package at.htl.model;

import java.util.Map;

public class FakeChallengeData {

    public static Map<String, ChallengeCategoryDTO> challengesByCategory = Map.of(
            "Fitness", new ChallengeCategoryDTO(
                    "Beweise deine Kraft und bleib in Bewegung!",
                    new String[] {
                            "20 Liegestütze machen",
                            "1 Minute Plank halten",
                            "10 Kniebeugen mit Sprung",
                            "30 Sekunden Hampelmänner",
                            "5 Minuten zügig laufen oder joggen"
                    }
            ),
            "Suchen", new ChallengeCategoryDTO(
                    "Entdecke spannende Dinge in deiner Umgebung.",
                    new String[] {
                            "Fotografiere Hausnummer 5",
                            "Finde und fotografiere 3 rote Autos",
                            "Mache ein Foto von einem Stoppschild",
                            "Finde ein Tier und mache ein Foto davon",
                            "Fotografiere etwas, das die Farbe Gelb hat"
                    }
            ),
            "Mutprobe", new ChallengeCategoryDTO(
                    "Zeig Mut – verlasse deine Komfortzone!",
                    new String[] {
                            "Singe laut ein Lied in der Öffentlichkeit",
                            "Frage eine fremde Person nach einem High-Five",
                            "Dusche 30 Sekunden eiskalt",
                            "Rufe jemanden an und sage ihm, dass du ihn magst",
                            "Iss etwas Ungewöhnliches (z. B. Zitrone pur)"
                    }
            ),
            "Wissen", new ChallengeCategoryDTO(
                    "Teste dein Wissen über die Welt!",
                    new String[] {
                            "Wie viele Kontinente gibt es auf der Erde?",
                            "Was ist die Hauptstadt von Kanada?",
                            "Welches chemische Symbol steht für Gold?",
                            "Nenne drei Planeten unseres Sonnensystems",
                            "Welches Jahr gilt als Beginn des Internetzeitalters?"
                    }
            )
    );
}
