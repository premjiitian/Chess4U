import SwiftUI

// MARK: - Import Games View
/// Lets the player connect their chess.com or Lichess account by entering a
/// username, fetches their recent games, and opens the analysis board on any game.
struct ImportGamesView: View {
    @EnvironmentObject var appState: AppState

    @ObservedObject private var service = ExternalPlatformService.shared
    @ObservedObject private var syncService = GameSyncService.shared
    @State private var selectedPlatform: ExternalGame.Platform = .chesscom
    @State private var username: String = ""
    @State private var showingAnalysis: Bool = false
    @State private var gameToAnalyze: ChessGame? = nil
    @State private var externalGameToAnalyze: ExternalGame? = nil
    @State private var showingMyPuzzles: Bool = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                platformPicker
                usernameField
                syncButton
                if let summary = syncService.lastSyncSummary {
                    syncSummaryBanner(summary)
                }
                fetchButton

                if service.isFetching {
                    ProgressView("Fetching games…")
                        .padding(40)
                    Spacer()
                } else if let error = service.lastError {
                    errorView(error)
                } else if service.recentGames.isEmpty {
                    emptyState
                } else {
                    gamesList
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Import Games")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingMyPuzzles = true
                    } label: {
                        Label("My Puzzles", systemImage: "star.fill")
                    }
                }
            }
            .sheet(isPresented: $showingMyPuzzles) {
                NavigationView { MyPuzzlesView() }
            }
            .onAppear(perform: loadSavedUsername)
            .sheet(isPresented: $showingAnalysis) {
                if let game = gameToAnalyze {
                    NavigationView {
                        GameAnalysisView(game: game, sourceGame: externalGameToAnalyze)
                            .navigationTitle("Game Analysis")
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("Done") { showingAnalysis = false }
                                }
                            }
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Sub-views

    var platformPicker: some View {
        Picker("Platform", selection: $selectedPlatform) {
            Text("chess.com").tag(ExternalGame.Platform.chesscom)
            Text("Lichess").tag(ExternalGame.Platform.lichess)
        }
        .pickerStyle(.segmented)
        .padding()
        .background(Color(.systemBackground))
        .onChange(of: selectedPlatform) { _ in
            loadSavedUsername()
            service.recentGames = []
            service.lastError = nil
        }
    }

    var usernameField: some View {
        HStack {
            Image(systemName: selectedPlatform == .chesscom ? "chess.com" : "person.fill")
                .foregroundColor(.secondary)
                .imageScale(.medium)
            TextField(
                selectedPlatform == .chesscom ? "chess.com username" : "Lichess username",
                text: $username
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.URL)
        }
        .padding()
        .background(Color(.systemBackground))
    }

    var syncButton: some View {
        VStack(spacing: 0) {
            Button {
                saveUsername()
                Task {
                    await syncService.syncRecentGames(
                        platform: selectedPlatform,
                        username: username,
                        days: 30,
                        profile: appState.playerProfile
                    )
                }
            } label: {
                HStack {
                    if syncService.isSyncing {
                        ProgressView().tint(.white)
                        Text(syncService.progressText.isEmpty ? "Syncing…" : syncService.progressText)
                    } else {
                        Label("Sync Last 30 Days \u{2192} Build Puzzles", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(username.count >= 2 ? AppTheme.accent : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(14)
                .font(.subheadline)
                .fontWeight(.semibold)
            }
            .disabled(username.count < 2 || syncService.isSyncing)
            .padding(.horizontal)
            .padding(.top, 8)

            if let error = syncService.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .padding(.top, 4)
            }
        }
        .background(Color(.systemBackground))
    }

    func syncSummaryBanner(_ summary: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppTheme.accent)
            Text(summary)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Button {
                showingMyPuzzles = true
            } label: {
                Text("View")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(AppTheme.accentLight)
    }

    var fetchButton: some View {
        Button {
            saveUsername()
            Task { await service.fetchGames(platform: selectedPlatform, username: username) }
        } label: {
            Label("Fetch Recent Games", systemImage: "arrow.down.circle.fill")
                .frame(maxWidth: .infinity)
                .padding()
                .background(username.count >= 2 ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(14)
                .font(.headline)
        }
        .disabled(username.count < 2)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    var gamesList: some View {
        List(service.recentGames) { game in
            Button {
                analyzeGame(game)
            } label: {
                GameRowView(game: game)
            }
            .listRowBackground(Color(.systemBackground))
        }
        .listStyle(.insetGrouped)
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "square.grid.3x3.middleleft.filled")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No games loaded yet")
                .font(.headline)
            Text("Enter your \(selectedPlatform.rawValue) username and tap Fetch.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text("Could not fetch games")
                .font(.headline)
            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - Actions

    private func analyzeGame(_ external: ExternalGame) {
        if let game = PGNImporter.importGame(external.pgn) {
            gameToAnalyze = game
            externalGameToAnalyze = external
            showingAnalysis = true
        }
    }

    private func loadSavedUsername() {
        let key = selectedPlatform == .chesscom ? "chesscomUsername" : "lichessUsername"
        username = UserDefaults.standard.string(forKey: key) ?? ""
    }

    private func saveUsername() {
        let key = selectedPlatform == .chesscom ? "chesscomUsername" : "lichessUsername"
        UserDefaults.standard.set(username, forKey: key)
    }
}

// MARK: - Game Row
struct GameRowView: View {
    let game: ExternalGame

    var resultColor: Color {
        switch game.result {
        case "1-0": return .green
        case "0-1": return .red
        default:    return .blue
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Platform badge
            Text(game.platform == .chesscom ? "♟" : "L")
                .font(.title2)
                .foregroundColor(game.platform == .chesscom ? .green : .purple)
                .frame(width: 36, height: 36)
                .background(
                    (game.platform == .chesscom ? Color.green : Color.purple).opacity(0.12)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("♔ \(game.whitePlayer)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("vs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("♚ \(game.blackPlayer)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                HStack(spacing: 8) {
                    Text(game.result)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(resultColor)
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(game.timeControl)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(game.endTime, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
