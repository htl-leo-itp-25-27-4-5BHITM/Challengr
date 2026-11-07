import SwiftUI

/// Rahmengeschichte „Der Challengr-Blitz“: Einleitung zum Durchblättern, darunter die Kapitel der Figuren.
/// Kapitel gesperrter Figuren bleiben verdeckt, bis man die Figur freischaltet.
struct StoryView: View {
    @Environment(\.dismiss) private var dismiss

    // MARK: - Input (Eingaben)
    let isUnlocked: (GameCharacter) -> Bool
    let lockedHint: (GameCharacter) -> String

    @State private var page = 0
    @State private var openCharacter: GameCharacter?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                Text(ChallengrStory.title.uppercased())
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.challengrYellow)
                    .padding(.top, 22)

                TabView(selection: $page) {
                    ForEach(Array(ChallengrStory.intro.enumerated()), id: \.element.id) { index, p in
                        introPage(p).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 250)

                Text("DIE KÄMPFER")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 10) {
                    ForEach(GameCharacter.allCases) { c in chapterRow(c) }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(GameStyle.background.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .presentationDragIndicator(.visible)
        .sheet(item: $openCharacter) { c in
            CharacterStoryView(character: c)
        }
    }

    private func introPage(_ p: ChallengrStory.Page) -> some View {
        VStack(spacing: 12) {
            Image(systemName: p.systemImage)
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(.challengrYellow)
                .shadow(color: .challengrYellow.opacity(0.6), radius: 12)
            Text(p.title)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(.white)
            Text(p.text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .gamePanel(padding: 0, cornerRadius: 22, highlight: .challengrYellow)
        .padding(.bottom, 30)   // Platz für die Seitenpunkte
    }

    private func chapterRow(_ c: GameCharacter) -> some View {
        let unlocked = isUnlocked(c)
        return Button {
            if unlocked { openCharacter = c }
        } label: {
            HStack(spacing: 12) {
                Image(c.avatarImageName)
                    .resizable()
                    .scaledToFill()
                    .colorMultiply(unlocked ? .white : .black)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(unlocked ? c.themeColor : Color.white.opacity(0.12)))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(unlocked ? c.displayName.uppercased() : "???")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(.white)
                    Text(unlocked ? c.chapterTitle : "Gesperrt · \(lockedHint(c))")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer(minLength: 0)
                Image(systemName: unlocked ? "book.fill" : "lock.fill")
                    .foregroundStyle(unlocked ? Color.challengrYellow : Color.white.opacity(0.4))
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(GameStyle.panelFill))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(unlocked ? "\(c.displayName): \(c.chapterTitle)" : "Gesperrtes Kapitel, \(lockedHint(c))")
    }
}

/// Steckbrief einer Figur: Kapitel, Lieblingsspruch, Erzrivale.
struct CharacterStoryView: View {
    let character: GameCharacter

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                Image(character.avatarImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 110, height: 110)
                    .background(Circle().fill(character.themeColor))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 3))
                    .padding(.top, 26)

                VStack(spacing: 4) {
                    Text(character.displayName.uppercased())
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .tracking(1.4)
                    Text(character.tagline.uppercased())
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Text("„\(character.motto)“")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .italic()
                    .foregroundStyle(.challengrYellow)

                VStack(alignment: .leading, spacing: 8) {
                    Text(character.chapterTitle.uppercased())
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.6))
                    Text(character.story)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .gamePanel(padding: 16, cornerRadius: 20, highlight: character.themeColor)

                if let rival = character.rival {
                    HStack(spacing: 12) {
                        Image(rival.avatarImageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(rival.themeColor))
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ERZRIVALE")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .tracking(1.4)
                                .foregroundStyle(Color.challengrRed)
                            Text(rival.displayName)
                                .font(.system(size: 16, weight: .black, design: .rounded))
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "bolt.fill").foregroundStyle(Color.challengrRed)
                    }
                    .gamePanel(padding: 12, cornerRadius: 18, highlight: .challengrRed)
                    .accessibilityElement(children: .combine)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(GameStyle.background.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
