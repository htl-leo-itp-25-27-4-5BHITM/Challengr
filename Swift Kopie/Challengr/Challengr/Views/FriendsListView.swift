import SwiftUI
import CoreLocation
import UniformTypeIdentifiers

struct FriendsListView: View {
    private let challengrRed = Color(red: 0.73, green: 0.12, blue: 0.20)
    private let challengrDark = Color(red: 0.12, green: 0.00, blue: 0.05)
    private let cardBackground = Color.white

    // MVP inputs
    let ownPlayerId: String
    let currentCoordinate: CLLocationCoordinate2D
    var allChallenges: [ChallengeDTO] = []
    var socket: GameSocketService? = nil
    var radiusMeters: Double = 250

    @StateObject private var vm = FriendsViewModel()

    @State private var searchText: String = ""
    @State private var appliedSearch: String = ""
    @State private var selectedBondLevel: Int = 0

    @State private var showAddFriendSheet: Bool = false

    @State private var showIncomingPopup: Bool = false
    @State private var pendingIncomingPopup: Bool = false
    @State private var incomingFromName: String = ""
    @State private var incomingRequestId: Int64? = nil
    @State private var incomingFromPlayerId: String? = nil
    @State private var selectedBattleFriend: PlayerDTO? = nil
    @State private var openedGift: OpenedGiftPresentation? = nil

    private let playerService = PlayerLocationService()

    init(
        ownPlayerId: String,
        currentCoordinate: CLLocationCoordinate2D,
        allChallenges: [ChallengeDTO] = [],
        socket: GameSocketService? = nil,
        radiusMeters: Double = 250
    ) {
        self.ownPlayerId = ownPlayerId
        self.currentCoordinate = currentCoordinate
        self.allChallenges = allChallenges
        self.socket = socket
        self.radiusMeters = radiusMeters
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Freunde")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(challengrDark)

                HStack(spacing: 12) {
                    FriendActionButton(
                        icon: "person.badge.plus",
                        title: "Hinzufügen",
                        foreground: challengrRed,
                        background: challengrRed.opacity(0.12),
                        action: {
                            showAddFriendSheet = true
                        }
                    )

                    FriendActionButton(
                        icon: "magnifyingglass",
                        title: "Suchen",
                        foreground: challengrDark,
                        background: challengrDark.opacity(0.08),
                        action: {
                            appliedSearch = searchText
                        }
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    TextField("Freund suchen", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(challengrDark.opacity(0.12), lineWidth: 1)
                        )
                        .onSubmit {
                            appliedSearch = searchText
                        }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Freundschaftslevel filtern")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)

                        Picker("Freundschaftslevel", selection: $selectedBondLevel) {
                            Text("Alle").tag(0)
                            Text("1").tag(1)
                            Text("2").tag(2)
                            Text("3").tag(3)
                            Text("4").tag(4)
                            Text("5").tag(5)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                if !vm.incomingGifts.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Geschenke")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)

                        ForEach(vm.incomingGifts) { gift in
                            GiftInboxRow(
                                senderName: giftSenderName(for: gift),
                                challengrRed: challengrRed,
                                cardBackground: cardBackground
                            ) {
                                Task {
                                    let senderName = giftSenderName(for: gift)
                                    let claimed = await vm.claimGift(giftId: gift.id, ownPlayerId: ownPlayerId)
                                    if claimed {
                                        openedGift = OpenedGiftPresentation(senderName: senderName)
                                    }
                                }
                            }
                        }
                    }
                }

                // Friends list
                VStack(alignment: .leading, spacing: 10) {
                    Text("Deine Freunde")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary)

                    if vm.friends.isEmpty {
                        Text("Noch keine Freunde. Füge Leute aus deiner Nähe hinzu.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(filteredFriends) { friend in
                            let distanceMeters = distanceToFriend(friend)
                            FriendRow(
                                player: friend,
                                distanceText: distanceLabel(for: distanceMeters),
                                isNearby: isNearbyForBattle(distanceMeters),
                                challengrRed: challengrRed,
                                challengrDark: challengrDark,
                                cardBackground: cardBackground,
                                showsBattleAction: isNearbyForBattle(distanceMeters) && socket != nil && !allChallenges.isEmpty,
                                onBattle: {
                                    selectedBattleFriend = friend
                                },
                                onSendGift: {
                                    Task {
                                        await vm.sendGift(ownPlayerId: ownPlayerId, to: friend.id)
                                    }
                                },
                                onRemove: {
                                    Task {
                                        await vm.removeFriend(ownPlayerId: ownPlayerId, friendId: friend.id)
                                    }
                                }
                            )
                        }
                    }
                }
                .padding(.top, 6)

                // Nearby suggestions
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("In der Nähe")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)

                        Spacer()

                        if vm.isLoadingNearby {
                            ProgressView()
                                .scaleEffect(0.9)
                        } else {
                            Button("Neu laden") {
                                Task {
                                    await vm.loadAll(
                                        ownPlayerId: ownPlayerId,
                                        coordinate: currentCoordinate,
                                        radiusMeters: radiusMeters
                                    )
                                }
                            }
                            .font(.system(size: 13, weight: .semibold))
                        }
                    }

                    if let error = vm.errorText {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }

                    if !vm.isLoadingNearby && vm.nearbyPlayers.isEmpty {
                        Text("Niemand in deinem Radius gefunden.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 6)
                    }

                    ForEach(vm.nearbyPlayers) { player in
                        NearbyPlayerRow(
                            player: player,
                            challengrRed: challengrRed,
                            challengrDark: challengrDark,
                            cardBackground: cardBackground,
                            isPending: vm.pendingOutgoingToPlayerIds.contains(player.id)
                        ) {
                            Task {
                                await vm.sendRequest(ownPlayerId: ownPlayerId, to: player.id)
                            }
                        }
                    }
                }
                .padding(.top, 10)

                Spacer(minLength: 12)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showAddFriendSheet) {
            AddFriendSheet(
                ownPlayerId: ownPlayerId,
                onDidSendRequest: {
                    Task { await vm.loadAll(ownPlayerId: ownPlayerId, coordinate: currentCoordinate, radiusMeters: radiusMeters) }
                }
            )
            .presentationDetents([.medium])
        }
        .task {
            await vm.loadAll(
                ownPlayerId: ownPlayerId,
                coordinate: currentCoordinate,
                radiusMeters: radiusMeters
            )
        }
        .task {
            // Lightweight polling while the view is visible.
            // Polling too frequently can destabilize the connection on real devices.
            while !Task.isCancelled {
                await vm.pollIncomingOnce(playerId: ownPlayerId)
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5s
            }
        }
        .onChange(of: vm.incomingSignal) { _, _ in
            guard let req = vm.incomingRequest else { return }
            incomingRequestId = req.id
            incomingFromPlayerId = req.fromPlayerId
            // Show the sheet immediately with a placeholder, then replace with the real name.
            incomingFromName = "Lädt…"

            if showAddFriendSheet {
                pendingIncomingPopup = true
            } else {
                showIncomingPopup = true
            }

            Task {
                // Load sender for nicer UI (show name instead of id)
                if let dto = try? await playerService.loadPlayerById(id: req.fromPlayerId) {
                    incomingFromName = dto.name
                } else {
                    incomingFromName = req.fromPlayerId
                }
            }
        }
        .onChange(of: showAddFriendSheet) { _, isPresented in
            if !isPresented, pendingIncomingPopup, incomingRequestId != nil {
                pendingIncomingPopup = false
                showIncomingPopup = true
            }
        }
        .sheet(isPresented: $showIncomingPopup) {
            IncomingFriendRequestSheet(
                fromName: incomingFromName,
                fromPlayerId: incomingFromPlayerId,
                onAccept: {
                    guard let id = incomingRequestId else {
                        showIncomingPopup = false
                        return
                    }
                    Task {
                        await vm.acceptIncoming(requestId: id)
                        await vm.loadAll(
                            ownPlayerId: ownPlayerId,
                            coordinate: currentCoordinate,
                            radiusMeters: radiusMeters
                        )
                        showIncomingPopup = false
                    }
                },
                onDecline: {
                    guard let id = incomingRequestId else {
                        showIncomingPopup = false
                        return
                    }
                    Task {
                        await vm.declineIncoming(requestId: id)
                        showIncomingPopup = false
                    }
                }
            )
            .presentationDetents([.height(260)])
        }
        .sheet(item: $openedGift) { gift in
            GiftOpenedSheet(senderName: gift.senderName)
                .presentationDetents([.height(300)])
        }
        .overlay(friendBattleOverlay)
    }

    private var filteredFriends: [PlayerDTO] {
        let normalizedQuery = appliedSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return vm.friends }
        return vm.friends.filter {
            $0.name.localizedCaseInsensitiveContains(normalizedQuery) ||
            $0.id.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }

    private var friendBattleOverlay: some View {
        Group {
            if let friend = selectedBattleFriend, let socket {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            selectedBattleFriend = nil
                        }

                    ChallengeDialogView(
                        otherPlayerId: friend.id,
                        otherPlayerName: friend.name,
                        ownPlayerId: ownPlayerId,
                        allChallenges: allChallenges,
                        socket: socket
                    ) {
                        selectedBattleFriend = nil
                    }
                }
                .transition(.scale)
            }
        }
    }

    private func distanceToFriend(_ friend: PlayerDTO) -> Double? {
        let friendLocation = CLLocation(latitude: friend.latitude, longitude: friend.longitude)
        let ownLocation = CLLocation(latitude: currentCoordinate.latitude, longitude: currentCoordinate.longitude)
        return ownLocation.distance(from: friendLocation)
    }

    private func isNearbyForBattle(_ distanceMeters: Double?) -> Bool {
        guard let distanceMeters else { return false }
        return distanceMeters <= radiusMeters
    }

    private func distanceLabel(for distanceMeters: Double?) -> String {
        guard let distanceMeters else { return "Standort unbekannt" }
        if distanceMeters <= radiusMeters {
            return "In deiner Nähe"
        }
        if distanceMeters > 2_000 {
            return "Über 2 km entfernt"
        }
        if distanceMeters >= 1_000 {
            return String(format: "%.1f km entfernt", distanceMeters / 1_000)
        }
        return "\(Int(distanceMeters.rounded())) m entfernt"
    }

    private func giftSenderName(for gift: FriendGiftDTO) -> String {
        vm.friends.first(where: { $0.id == gift.fromPlayerId })?.name ?? "Ein Freund"
    }

    private struct OpenedGiftPresentation: Identifiable {
        let id = UUID()
        let senderName: String
    }
}

private struct FriendRow: View {
    let player: PlayerDTO
    let distanceText: String
    let isNearby: Bool
    let challengrRed: Color
    let challengrDark: Color
    let cardBackground: Color
    let showsBattleAction: Bool
    let onBattle: () -> Void
    let onSendGift: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 46, height: 46)
                        .foregroundColor(challengrDark.opacity(0.75))
                        .padding(6)
                        .background(challengrDark.opacity(0.08))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 6) {
                        Text(player.name)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(challengrDark)

                        Text("Punkte: \(player.points)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(challengrDark.opacity(0.75))

                        Text(distanceText)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isNearby ? .green : challengrDark.opacity(0.72))
                    }

                    Spacer(minLength: 0)
                }

                Button(action: onRemove) {
                    Image(systemName: "person.fill.xmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Circle().fill(Color.red.opacity(0.9)))
                }
                .buttonStyle(.plain)
                .buttonStyle(.borderless)
            }

            HStack(spacing: 10) {
                FriendActionButton(
                    icon: "gift.fill",
                    title: "Geschenk",
                    foreground: challengrRed,
                    background: challengrRed.opacity(0.12),
                    action: onSendGift
                )

                if showsBattleAction {
                    FriendActionButton(
                        icon: "bolt.fill",
                        title: "Battlen",
                        foreground: .green,
                        background: Color.green.opacity(0.14),
                        action: onBattle
                    )
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardBackground)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(challengrDark.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct IncomingFriendRequestSheet: View {
    let fromName: String
    let fromPlayerId: String?
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Capsule()
                .fill(Color.black.opacity(0.12))
                .frame(width: 44, height: 5)
                .padding(.top, 10)

            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .foregroundColor(Color.black.opacity(0.65))
                    .background(Color.black.opacity(0.06))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Freundschaftsanfrage")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(fromName)
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        if fromName == "Lädt…", let pid = fromPlayerId {
                            Text(pid)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)

            Text("Möchtest du die Anfrage annehmen?")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary.opacity(0.85))
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Button(action: onDecline) {
                    Text("Ablehnen")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.black.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)

                Button(action: onAccept) {
                    Text("Annehmen")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(red: 0.73, green: 0.12, blue: 0.20))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)

            Spacer(minLength: 8)
        }
        .background(Color(.systemBackground))
    }
}

struct FriendActionButton: View {
    let icon: String
    let title: String
    let foreground: Color
    let background: Color
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(foreground)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(background)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct GiftInboxRow: View {
    let senderName: String
    let challengrRed: Color
    let cardBackground: Color
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(challengrRed)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Geschenk erhalten")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)

                    Text("Von \(senderName)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(challengrRed.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct GiftOpenedSheet: View {
    let senderName: String

    @Environment(\.dismiss) private var dismiss
    @State private var animateGift = false

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Color.black.opacity(0.12))
                .frame(width: 44, height: 5)
                .padding(.top, 10)

            ZStack {
                Circle()
                    .fill(Color(red: 0.73, green: 0.12, blue: 0.20).opacity(0.12))
                    .frame(width: 110, height: 110)
                    .scaleEffect(animateGift ? 1.08 : 0.9)

                Image(systemName: "gift.fill")
                    .font(.system(size: 46, weight: .bold))
                    .foregroundColor(Color(red: 0.73, green: 0.12, blue: 0.20))
                    .scaleEffect(animateGift ? 1.0 : 0.6)
                    .rotationEffect(.degrees(animateGift ? 0 : -12))
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.62), value: animateGift)

            Text("Geschenk erhalten")
                .font(.system(size: 24, weight: .black, design: .rounded))

            Text("\(senderName) hat dir ein Geschenk geschickt.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)

            Button("Schließen") {
                dismiss()
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color(red: 0.73, green: 0.12, blue: 0.20))
            )
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .background(Color(.systemBackground))
        .onAppear {
            animateGift = true
        }
    }
}

private struct AddFriendSheet: View {
    let ownPlayerId: String
    let onDidSendRequest: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showQR: Bool = false
    @State private var showScanner: Bool = false
    @State private var showInviteImporter: Bool = false
    @State private var isImportingInvite: Bool = false
    @State private var shareInviteFile: ShareInviteFile? = nil
    @State private var importError: String? = nil
    @State private var shareError: String? = nil

    private let friendsService = FriendsService()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showQR = true
                    } label: {
                        Label("QR anzeigen", systemImage: "qrcode")
                    }

                    Button {
                        prepareShareInvite()
                    } label: {
                        Label("Per AirDrop teilen", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showScanner = true
                    } label: {
                        Label("QR scannen", systemImage: "camera.viewfinder")
                    }

                    Button {
                        showInviteImporter = true
                    } label: {
                        Label("AirDrop-Datei öffnen", systemImage: "square.and.arrow.down")
                    }
                    .disabled(isImportingInvite)
                } header: {
                    Text("Freund hinzufügen")
                } footer: {
                    Text("Du kannst eine Einladung als QR zeigen, per AirDrop teilen oder den QR von jemand anderem scannen. Wenn AirDrop nur eine Datei lädt, öffne sie hier.")
                }
            }
            .navigationTitle("Hinzufügen")
            .sheet(item: $shareInviteFile) { shareFile in
                ShareSheet(activityItems: [shareFile.url])
            }
            .fileImporter(
                isPresented: $showInviteImporter,
                allowedContentTypes: [.challengrFriendInvite, .data, .plainText]
            ) { result in
                importInvite(from: result)
            }
            .alert("Teilen fehlgeschlagen", isPresented: Binding(
                get: { shareError != nil },
                set: { if !$0 { shareError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(shareError ?? "")
            }
            .alert("Import fehlgeschlagen", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importError ?? "")
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
            .sheet(isPresented: $showQR) {
                FriendInviteQRView(ownPlayerId: ownPlayerId)
            }
            .sheet(isPresented: $showScanner) {
                FriendInviteScannerView(ownPlayerId: ownPlayerId) {
                    onDidSendRequest()
                    dismiss()
                }
            }
        }
    }

    private func prepareShareInvite() {
        do {
            shareError = nil
            shareInviteFile = ShareInviteFile(url: try FriendInviteTransfer.makeTemporaryInviteFile(fromPlayerId: ownPlayerId))
        } catch {
            shareError = "Die AirDrop-Einladung konnte nicht erstellt werden."
        }
    }

    private func importInvite(from result: Result<URL, Error>) {
        guard !isImportingInvite else { return }

        switch result {
        case .success(let url):
            isImportingInvite = true
            importError = nil

            Task {
                do {
                    let fromPlayerId = try FriendInvitePayload.parseIncomingURL(url)

                    guard fromPlayerId != ownPlayerId else {
                        await MainActor.run {
                            isImportingInvite = false
                            importError = "Das ist deine eigene Einladung."
                        }
                        return
                    }

                    try await friendsService.sendFriendRequest(from: ownPlayerId, to: fromPlayerId)

                    await MainActor.run {
                        isImportingInvite = false
                        onDidSendRequest()
                        dismiss()
                    }
                } catch {
                    await MainActor.run {
                        isImportingInvite = false
                        importError = (error as? LocalizedError)?.errorDescription ?? "Die Einladung konnte nicht importiert werden."
                    }
                }
            }
        case .failure:
            importError = "Die Einladung konnte nicht geöffnet werden."
        }
    }

    private struct ShareInviteFile: Identifiable {
        let id = UUID()
        let url: URL
    }
}

private struct NearbyPlayerRow: View {
    let player: PlayerDTO
    let challengrRed: Color
    let challengrDark: Color
    let cardBackground: Color
    let isPending: Bool
    let onRequest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .foregroundColor(challengrDark.opacity(0.75))
                    .padding(6)
                    .background(challengrDark.opacity(0.08))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 6) {
                    Text(player.name)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(challengrDark)

                    Text("Punkte: \(player.points)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(challengrDark.opacity(0.8))
                }

                Spacer()

                Button {
                    onRequest()
                } label: {
                    Text(isPending ? "GESENDET" : "ANFRAGEN")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .tracking(0.8)
                        .foregroundColor(isPending ? .secondary : challengrDark)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(isPending ? Color.gray.opacity(0.12) : challengrRed.opacity(0.18))
                        )
                }
                .buttonStyle(.plain)
                .disabled(isPending)
            }
        }
        .padding(14)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(challengrRed.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 4)
    }
}
