import SwiftUI
import CoreLocation

struct FriendsListView: View {
    private let challengrRed = Color(red: 0.73, green: 0.12, blue: 0.20)
    private let challengrDark = Color(red: 0.12, green: 0.00, blue: 0.05)
    private let cardBackground = Color.white

    // MVP inputs
    let ownPlayerId: String
    let currentCoordinate: CLLocationCoordinate2D
    var radiusMeters: Double = 250

    @StateObject private var vm = FriendsViewModel()

    @State private var searchText: String = ""
    @State private var appliedSearch: String = ""
    @State private var selectedBondLevel: Int = 0

    @State private var showIncomingPopup: Bool = false
    @State private var incomingFromName: String = ""
    @State private var incomingRequestId: Int64? = nil

    private let playerService = PlayerLocationService()
    
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
                        background: challengrRed.opacity(0.12)
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
                        ForEach(vm.friends) { friend in
                            FriendRow(
                                player: friend,
                                challengrDark: challengrDark,
                                cardBackground: cardBackground,
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
        .task {
            await vm.loadAll(
                ownPlayerId: ownPlayerId,
                coordinate: currentCoordinate,
                radiusMeters: radiusMeters
            )
        }
        .task {
            // Lightweight polling while the view is visible.
            // This ensures the receiver sees a popup without needing to restart.
            while !Task.isCancelled {
                await vm.pollIncomingOnce(playerId: ownPlayerId)
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s
            }
        }
        .onChange(of: vm.incomingRequest?.id) { _, _ in
            guard let req = vm.incomingRequest else { return }
            incomingRequestId = req.id
            Task {
                // Load sender for nicer UI (show name instead of id)
                if let dto = try? await playerService.loadPlayerById(id: req.fromPlayerId) {
                    incomingFromName = dto.name
                } else {
                    incomingFromName = req.fromPlayerId
                }
                showIncomingPopup = true
            }
        }
        .sheet(isPresented: $showIncomingPopup) {
            IncomingFriendRequestSheet(
                fromName: incomingFromName,
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
    }
}

private struct FriendRow: View {
    let player: PlayerDTO
    let challengrDark: Color
    let cardBackground: Color
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 46, height: 46)
                .foregroundColor(challengrDark.opacity(0.75))
                .padding(6)
                .background(challengrDark.opacity(0.08))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(player.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(challengrDark)

                Text("Punkte: \(player.points)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(challengrDark.opacity(0.75))
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "person.fill.xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Circle().fill(Color.red.opacity(0.9)))
            }
            .buttonStyle(.plain)
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
                    Text(fromName)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
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
