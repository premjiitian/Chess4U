import SwiftUI

// MARK: - Connect Platform View
/// Quick-start onboarding path: create a profile straight from a real
/// chess.com/Lichess account instead of manually filling out the full
/// assessment. Uses only public, unauthenticated profile endpoints (no
/// real login) -- the player just confirms it's their account.
struct ConnectPlatformView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.presentationMode) var presentationMode

    @State private var platform: ExternalGame.Platform = .chesscom
    @State private var username: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    private let service = ExternalPlatformService.shared

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "link.circle.fill")
                            .font(.system(size: 56))
                            .foregroundColor(AppTheme.accent)
                        Text("Connect Your Account")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("We'll pull in your current rating so your training starts at the right level. No password needed -- just your public username.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 32)

                    Picker("Platform", selection: $platform) {
                        Text("chess.com").tag(ExternalGame.Platform.chesscom)
                        Text("Lichess").tag(ExternalGame.Platform.lichess)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.secondary)
                        TextField(
                            platform == .chesscom ? "chess.com username" : "Lichess username",
                            text: $username
                        )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2)))
                    .padding(.horizontal)

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
            }

            Button {
                connect()
            } label: {
                HStack {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                    }
                    Text(isLoading ? "Connecting…" : "Connect & Start Training")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(username.trimmingCharacters(in: .whitespaces).count >= 2 ? AppTheme.accent : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(16)
                .font(.headline)
            }
            .disabled(username.trimmingCharacters(in: .whitespaces).count < 2 || isLoading)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Connect Account")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func connect() {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let quick = try await service.fetchQuickProfile(platform: platform, username: trimmed)
                await MainActor.run {
                    createProfile(from: quick)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Couldn't find that \(platform.rawValue) account. Check the username and try again."
                }
            }
        }
    }

    private func createProfile(from quick: ExternalPlatformService.QuickProfile) {
        let elo = quick.rating ?? 1000
        var profile = PlayerProfile(
            name: quick.displayName?.isEmpty == false ? quick.displayName! : quick.username,
            connectedPlatform: platform.rawValue,
            connectedUsername: quick.username,
            elo: elo,
            preferredTimeControl: .rapid,
            playerType: .casual,
            mainOpeningsWhite: [],
            mainDefensesBlack: [],
            ratingTrend: .stable,
            weaknesses: [.tactics]
        )
        profile.tacticsAccuracy = 50.0
        profile.openingAccuracy = 50.0
        profile.endgameAccuracy = 50.0
        profile.calculationScore = 50.0
        profile.strategyScore = 50.0

        // Pre-fill Import Games' saved username so syncing games later is one tap.
        let key = platform == .chesscom ? "chesscomUsername" : "lichessUsername"
        UserDefaults.standard.set(quick.username, forKey: key)

        appState.savePlayerProfile(profile)
    }
}
