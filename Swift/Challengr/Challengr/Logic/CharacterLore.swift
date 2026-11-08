import Foundation

/// Rahmengeschichte „Der Challengr-Blitz“ und die Kapitel der Figuren.
/// Nur App-Texte – der Server weiß davon nichts.
enum ChallengrStory {
    struct Page: Identifiable {
        let title: String
        let text: String
        let systemImage: String
        var id: String { title }
    }

    static let title = "Der Challengr-Blitz"

    static let intro: [Page] = [
        Page(title: "DER BLITZ",
             text: "Eines Nachts schlug ein gelber Blitz mitten in der Stadt ein. Seitdem flackert er über den Dächern – und er hat Risse geöffnet. Risse in andere Zeiten und Welten.",
             systemImage: "bolt.fill"),
        Page(title: "DIE RISSE",
             text: "Durch die Risse stolpern Kämpfer aus allen Epochen: ein Ritter, ein Wikinger, ein Samurai, ein Ninja, ein Zauberer, ein Pirat. Alle wollen dasselbe: zurück nach Hause.",
             systemImage: "sparkles"),
        Page(title: "DIE LIGA",
             text: "Der Blitz lässt nur gehen, wer ihn auflädt – nicht mit Schwertern, sondern mit Challenges. Sprints, Quizfragen, Reaktion, Mut. Jedes Battle in der Stadt lädt ihn ein Stück auf.",
             systemImage: "trophy.fill"),
        Page(title: "UND DU?",
             text: "Du hast den Blitz als Erster gesehen. Jetzt stehst du mitten in der Challengr-Liga. Fordere heraus, schalte die Kämpfer frei und lies ihre Geschichten.",
             systemImage: "figure.boxing")
    ]
}

extension GameCharacter {
    /// Titel des eigenen Kapitels in der Rahmengeschichte.
    var chapterTitle: String {
        switch self {
        case .junge:      return "Der Erste am Fenster"
        case .maedchen:   return "Die mit dem Notizbuch"
        case .sirBrecht:  return "Der Ritter ohne Burg"
        case .ragnar:     return "Der Lauteste aus dem Norden"
        case .hayato:     return "Der Weg des Konters"
        case .kage:       return "Schatten ohne Auftrag"
        case .kai:        return "Das Gesicht der Liga"
        case .merlo:      return "Der die Risse liest"
        case .lyra:       return "Die Spurenleserin"
        case .kaeptnRex:  return "Der Schatz im Blitz"
        case .crashDummy: return "Testobjekt Nr. 1"
        case .frost:      return "Mit dem ersten Schnee"
        case .sirBrechtBlitz: return "Der Blitzgeborene"
        case .kaeptnRexJaeger: return "Der Jäger der Könige"
        case .glitch:     return "Fehler im System"
        }
    }

    /// Steckbrief und Kapitel in einem: woher die Figur kommt und was sie will.
    var story: String {
        switch self {
        case .junge:
            return "Er hat den Blitz einschlagen sehen, mit dem Handy in der Hand. Am nächsten Morgen war da diese App. Wer sie geschickt hat, weiß er nicht – aber er hat sofort auf „Herausfordern“ gedrückt."
        case .maedchen:
            return "Sie war vor allen anderen beim Einschlag und hat als Einzige ein Foto vom ersten Riss. Seitdem schreibt sie auf, wer aus welchem Riss kommt. Überholen lässt sie sich von niemandem – am wenigsten vom Jungen von gegenüber."
        case .sirBrecht:
            return "Er kam durch den ersten Riss, mitten aus einem Turnier. Er suchte seine Burg und fand einen Supermarkt. Seitdem steht fest: Wenn es hier Turniere gibt, gewinnt er sie – mit Ehre und einem einzigen sauberen Hieb."
        case .ragnar:
            return "Sein Langschiff fuhr in einen Sturm, und plötzlich stand er auf einem Parkplatz. Für ihn ist die Stadt ein neues Land, das erobert werden muss – Battle für Battle. Seit Sir Brecht ihn einmal besiegt hat, will er nur noch eins: Revanche."
        case .hayato:
            return "Er meditierte unter einem Kirschbaum, als der Riss ihn holte. Hayato greift nie zuerst an. Er wartet, beobachtet – und kontert im perfekten Moment. Dass ihm ein Ninja durch den Riss gefolgt ist, macht ihn unruhig."
        case .kage:
            return "Niemand hat Kage durch einen Riss kommen sehen. Er war einfach plötzlich da. Man sagt, er sei Hayato gefolgt, um ein altes Duell zu beenden. Kage sagt dazu nichts. Kage sagt nie etwas."
        case .kai:
            return "Kai hat in der Stadt schon gekämpft, bevor der Blitz kam – bei Straßenturnieren, mit Bandana und viel zu viel Selbstvertrauen. Als die Kämpfer aus den Rissen auftauchten, sagte er als Erster: „Dann eben eine Liga.“ Nur Lyra ist auf der Laufstrecke schneller. Noch."
        case .merlo:
            return "Merlo ist nicht hineingestolpert – er hat den Riss mit Absicht geöffnet, um den Blitz zu erforschen. Er weiß mehr darüber als alle anderen, verrät es aber nur in Quizfragen. Dass Käpt'n Rex ihm das Zauberbuch abschwatzen will, findet er gar nicht lustig."
        case .lyra:
            return "Lyra kommt aus einem Wald, der nie aufhörte. Jetzt läuft sie durch Parks und Gassen und kennt jeden Check-in-Spot der Stadt. Kai behauptet, er sei schneller. Lyra lacht nur und läuft los."
        case .kaeptnRex:
            return "Käpt'n Rex glaubt, der Blitz ist ein Schatz – und Schätze gehören Piraten. Sein Schiff hängt irgendwo zwischen zwei Rissen fest, nur der Papagei ist mitgekommen. Rex gewinnt selten fair, aber immer mit Stil. Merlo traut ihm keinen Meter."
        case .crashDummy:
            return "Der Crash-Test-Dummy stand im Labor genau unter dem Einschlag. Seitdem kann er sich bewegen und will alles ausprobieren. Er war der erste Tester der Liga und ist heute Trainingspartner für alle, die üben wollen. Er verliert gern. Meistens."
        case .frost:
            return "Frost kam mit dem Winter, durch einen eisigen Riss oben am Berg, das Board unterm Arm. Wo sie fährt, gefriert der Boden. Die Liga ist ihr zu langsam – und das will sie ändern."
        case .sirBrechtBlitz:
            return "Man erzählt sich, Sir Brecht sei einmal ganz oben in der Liga angekommen – und der Blitz sei direkt in sein Schwert gefahren. Seitdem glüht seine Rüstung schwarz und gold, und über seinem Helm schwebt eine Krone aus Licht. Nur wer selbst den Rang Challengr erreicht, bekommt ihn je zu sehen."
        case .kaeptnRexJaeger:
            return "Irgendwann hat Käpt'n Rex aufgehört, Schätze zu jagen – und angefangen, Könige zu jagen. Mit Halstuch, Raben und einer Klinge, die rot glüht, holt er sich jedes Kopfgeld der Stadt. Wer ihn so sieht, weiß: Fünf Könige sind schon gefallen."
        case .glitch:
            return "Der Blitz hat nicht nur Risse in die Stadt geschlagen – einer ging mitten durch den Trainings-Dummy. Wer oft genug absichtlich gegen ihn verliert, bringt den Riss zum Flackern. Und dann bricht etwas heraus, das eigentlich gar nicht existieren dürfte."
        }
    }

    /// Lieblingsspruch für den Steckbrief.
    var motto: String {
        switch self {
        case .junge:      return "Wer zuerst drückt, gewinnt."
        case .maedchen:   return "Steht schon in meinem Buch."
        case .sirBrecht:  return "Ein Hieb genügt."
        case .ragnar:     return "LAUTER!"
        case .hayato:     return "Geduld schlägt Eile."
        case .kage:       return "…"
        case .kai:        return "Dann eben eine Liga."
        case .merlo:      return "Wissen ist die stärkste Magie."
        case .lyra:       return "Versuch mitzuhalten."
        case .kaeptnRex:  return "Glück? Nein. Stil!"
        case .crashDummy: return "Aua. Nochmal!"
        case .frost:      return "Cool bleiben."
        case .sirBrechtBlitz: return "Ein Hieb. Ein Blitz. Aus."
        case .kaeptnRexJaeger: return "Jeder König fällt."
        case .glitch:     return "F̷e̷h̷l̷e̷r̷ ̷4̷0̷4̷"
        }
    }

    /// Erzrivale – trifft man im Battle aufeinander, wird es ein Rivalen-Duell.
    var rival: GameCharacter? {
        switch self {
        case .junge:      return .maedchen
        case .maedchen:   return .junge
        case .sirBrecht:  return .ragnar
        case .ragnar:     return .sirBrecht
        case .hayato:     return .kage
        case .kage:       return .hayato
        case .merlo:      return .kaeptnRex
        case .kaeptnRex:  return .merlo
        case .kai:        return .lyra
        case .lyra:       return .kai
        case .crashDummy, .frost, .sirBrechtBlitz, .kaeptnRexJaeger, .glitch: return nil
        }
    }

    /// Was die Figur nach einem Sieg zum Verlierer sagt.
    var victoryLines: [String] {
        switch self {
        case .junge:      return ["Nicht schlecht – aber ich war schneller.", "Revanche? Jederzeit!"]
        case .maedchen:   return ["Notiert: ein Sieg mehr für mich.", "Das kommt in mein Buch."]
        case .sirBrecht:  return ["Ein Hieb. Mehr braucht es nicht.", "Du hast mit Ehre verloren."]
        case .ragnar:     return ["HAHA! Noch eine Runde für Ragnar!", "Lauter jubeln als ich kann keiner!"]
        case .hayato:     return ["Geduld schlägt Eile.", "Du hast zuerst angegriffen. Fehler."]
        case .kage:       return ["…", "Du hast mich nicht kommen sehen."]
        case .kai:        return ["Willkommen in der Liga!", "Das war erst das Aufwärmen."]
        case .merlo:      return ["Das stand alles in meinem Buch.", "Wissen ist die stärkste Magie."]
        case .lyra:       return ["Deine Spur hab ich schon von Weitem gesehen.", "Versuch mal mitzuhalten!"]
        case .kaeptnRex:  return ["Arrr! Die Trophäen nehm ich mit.", "Glück? Nein. Stil!"]
        case .crashDummy: return ["Aua. Aber gewonnen!", "Test bestanden."]
        case .frost:      return ["Zu langsam – eingefroren!", "Cool bleiben. Hab ich."]
        case .sirBrechtBlitz: return ["Ein Hieb. Ein Blitz. Aus.", "Der Blitz hat entschieden."]
        case .kaeptnRexJaeger: return ["Dein Kopfgeld gehört jetzt mir.", "Jeder König fällt."]
        case .glitch:     return ["D̷u̷ ̷h̷a̷s̷t̷ ̷v̷e̷r̷l̷o̷r̷e̷n̷.", "Fehler: Gegner nicht gefunden."]
        }
    }

    /// Skins zählen wie ihre Figur (Blitzritter gegen Ragnar ist auch ein Rivalen-Duell).
    func isRival(of other: GameCharacter?) -> Bool { other != nil && base.rival == other?.base }
}

extension BattleResultData {
    /// Figuren von Sieger und Verlierer (nur mit Backend-Daten, sonst nil).
    var winnerCharacter: GameCharacter? {
        guard let p = participants, let id = winnerId else { return nil }
        return id == p.fromId ? p.fromCharacter : id == p.toId ? p.toCharacter : nil
    }

    var loserCharacter: GameCharacter? {
        guard let p = participants, let id = loserId else { return nil }
        return id == p.fromId ? p.fromCharacter : id == p.toId ? p.toCharacter : nil
    }

    /// Haben sich zwei Erzrivalen gegenübergestanden?
    var isRivalDuel: Bool {
        guard let p = participants, let from = p.fromCharacter else { return false }
        return from.isRival(of: p.toCharacter)
    }

    /// Spruch im Niederlage-Screen: statt des allgemeinen „GG!“ spricht die Sieger-Figur.
    /// Für dasselbe Battle immer derselbe Spruch.
    var victoryQuote: (speaker: GameCharacter, text: String)? {
        guard trashTalk == "GG!", let winner = winnerCharacter else { return nil }
        let lines = winner.victoryLines
        let pick = Int((battleId ?? 0) % Int64(lines.count))
        return (winner, lines[pick])
    }
}
