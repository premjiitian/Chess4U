import SwiftUI

struct FreePlayView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = ChessBoardViewModel()
    @StateObject private var clock = ChessClockService()
    @State private var showingAnalysis = false
    @State private var showResignAlert = false
    @State private var showClockPicker = false
    @State private var vsMode: VsMode = .vsAI
    @State private var aiDepth: Int = 3
    @State private var clockPreset: ClockPreset = .none

    private let savedGameKey = "FreePlay_SavedGame"
    private let savedVsModeKey = "FreePlay_VsMode"

    enum VsMode: String, CaseIterable {
        case vsAI = "vs AI"
        case twoPlayer = "2 Players"
        case puzzlePosition = "Position Setup"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Game status bar
                statusBar

                // Black clock (top, shown only when clock is active)
                if clockPreset != .none {
                    ClockFaceView(clock: clock, color: vm.isFlipped ? .white : .black)
                        .padding(.horizontal)
                        .padding(.top, 4)
                }

                // Chess board — always a single view; interactive flag computed
                // so the view identity is stable across turn changes, which
                // prevents SwiftUI from unmounting/remounting on each AI move.
                ChessBoardView(
                    vm: vm,
                    interactive: vsMode == .twoPlayer || vm.game.board.activeColor == .white
                )
                .padding()
                .onChange(of: vm.game.moves.count) { _ in
                    // Press clock on each move
                    if clockPreset != .none { clock.pressClock() }
                    if vsMode == .vsAI && vm.game.board.activeColor == .black {
                        vm.makeAIMove(depth: aiDepth)
                    }
                }

                // White clock (bottom)
                if clockPreset != .none {
                    ClockFaceView(clock: clock, color: vm.isFlipped ? .black : .white)
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                }

                // Move list
                MoveListView(moves: vm.game.moves)
                    .frame(height: 60)

                // Control bar
                controlBar
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Free Play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showClockPicker = true
                    } label: {
                        Label(clockPreset == .none ? "Clock" : clockPreset.rawValue,
                              systemImage: "clock")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(VsMode.allCases, id: \.self) { mode in
                            Button(mode.rawValue) {
                                vsMode = mode
                                newGame()
                            }
                        }
                    } label: {
                        Label(vsMode.rawValue, systemImage: "ellipsis.circle")
                    }
                }
            }
            .confirmationDialog("Choose Time Control", isPresented: $showClockPicker, titleVisibility: .visible) {
                ForEach(ClockPreset.allCases, id: \.self) { preset in
                    Button(preset.rawValue) {
                        clockPreset = preset
                        clock.configure(preset: preset)
                        if preset != .none { clock.start() }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showingAnalysis) {
                GameAnalysisSheet(game: vm.game)
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            vm.settings = appState.settings
            vm.profile = appState.playerProfile
            restoreGame()
        }
        .onDisappear {
            saveGame()
        }
        .alert("Resign Game?", isPresented: $showResignAlert) {
            Button("Resign", role: .destructive) {
                vm.game.status = .resigned(vm.game.board.activeColor)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showingAnalysis = true
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to resign? This will end the current game.")
        }
        // Automatically prompt for post-game analysis when checkmate or stalemate.
        .onChange(of: vm.game.status) { status in
            switch status {
            case .checkmate:
                clock.pause()
                // White wins on checkmate when it's black's turn (black king is mated)
                let whiteWon = vm.game.board.activeColor == .black
                appState.recordGameCompleted(openingName: openingName,
                                             playerWon: vsMode == .vsAI ? whiteWon : nil,
                                             isDraw: false)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showingAnalysis = true }
            case .stalemate, .draw:
                clock.pause()
                appState.recordGameCompleted(openingName: openingName, playerWon: nil, isDraw: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showingAnalysis = true }
            case .resigned(let losingColor):
                clock.pause()
                let playerWon: Bool? = vsMode == .vsAI ? (losingColor != .white) : nil
                appState.recordGameCompleted(openingName: openingName, playerWon: playerWon, isDraw: false)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showingAnalysis = true }
            default: break
            }
        }
        // Clock flag = flagged player loses on time
        .onChange(of: clock.isFlagged) { flagged in
            guard flagged else { return }
            vm.game.status = .resigned(vm.game.board.activeColor)  // treat flag as resign for analysis
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showingAnalysis = true
            }
        }
    }

    var openingName: String? {
        ChessOpening.detect(moves: vm.game.moves.map { $0.longAlgebraic })
    }

    var statusBar: some View {
        HStack {
            Circle()
                .fill(vm.game.board.activeColor == .white ? Color.white : Color.black)
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(Color.gray, lineWidth: 1))

            VStack(alignment: .leading, spacing: 1) {
                Text(vm.statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                if let opening = openingName {
                    Text(opening)
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
            }

            Spacer()

            if vsMode == .vsAI {
                HStack(spacing: 4) {
                    Text("AI Depth:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("", selection: $aiDepth) {
                        Text("Easy").tag(2)
                        Text("Medium").tag(3)
                        Text("Hard").tag(4)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    var controlBar: some View {
        HStack(spacing: 20) {
            Button { vm.goToStart() } label: {
                Image(systemName: "backward.end.fill")
            }

            Button { vm.undoLastMove() } label: {
                Image(systemName: "arrow.uturn.backward")
            }

            Button {
                vm.isFlipped.toggle()
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .accessibilityLabel("Flip board")

            Button { newGame() } label: {
                Image(systemName: "plus.circle")
            }

            // Resign button — only shown during an active game vs AI
            if vsMode == .vsAI && vm.game.status == .active {
                Button {
                    showResignAlert = true
                } label: {
                    Image(systemName: "flag.fill")
                        .foregroundColor(.red)
                }
                .accessibilityLabel("Resign")
            }

            Spacer()

            // Share PGN
            if !vm.game.moves.isEmpty {
                ShareLink(item: vm.game.pgn, preview: SharePreview("Chess Game PGN")) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share game")
            }

            Button {
                showingAnalysis = true
            } label: {
                Label("Analyze", systemImage: "magnifyingglass")
                    .font(.subheadline)
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(10)
            }
        }
        .font(.title2)
        .foregroundColor(.primary)
        .padding()
        .background(Color(.systemBackground))
    }

    func newGame() {
        vm.game = ChessGame()
        vm.lastMove = nil
        UserDefaults.standard.removeObject(forKey: savedGameKey)
        clock.reset()
        if clockPreset != .none { clock.start() }
    }

    func saveGame() {
        guard vm.game.status == .active, !vm.game.moves.isEmpty else { return }
        if let data = try? JSONEncoder().encode(vm.game) {
            UserDefaults.standard.set(data, forKey: savedGameKey)
            UserDefaults.standard.set(vsMode.rawValue, forKey: savedVsModeKey)
        }
    }

    func restoreGame() {
        guard let data = UserDefaults.standard.data(forKey: savedGameKey),
              let saved = try? JSONDecoder().decode(ChessGame.self, from: data) else { return }
        vm.game = saved
        if let modeRaw = UserDefaults.standard.string(forKey: savedVsModeKey),
           let mode = VsMode(rawValue: modeRaw) {
            vsMode = mode
        }
    }
}

// MARK: - Clock Face View
struct ClockFaceView: View {
    @ObservedObject var clock: ChessClockService
    let color: PieceColor

    private var isActive: Bool { clock.isRunning && clock.activeColor == color }
    private var isLow: Bool { clock.isLowTime(for: color) }

    var body: some View {
        HStack {
            if color == .black { Spacer() }
            Text(clock.displayTime(for: color))
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(isLow ? .white : (color == .white ? .primary : .white))
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isLow ? Color.red : (isActive ? Color.green.opacity(0.85) : Color(.systemFill)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isActive ? Color.green : Color.clear, lineWidth: 2)
                )
                .animation(.easeInOut(duration: 0.3), value: isActive)
            if color == .white { Spacer() }
        }
    }
}

// MARK: - Move List View
struct MoveListView: View {
    let moves: [ChessMove]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(moves.enumerated()), id: \.offset) { idx, move in
                        HStack(spacing: 2) {
                            if idx % 2 == 0 {
                                Text("\(idx / 2 + 1).")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            Text(move.notation.isEmpty ? move.longAlgebraic : move.notation)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                        .id(idx)
                    }
                }
                .padding(.horizontal)
            }
            .onChange(of: moves.count) { _ in
                if let last = moves.indices.last {
                    withAnimation { proxy.scrollTo(last) }
                }
            }
        }
    }
}

// MARK: - Game Analysis Sheet
struct GameAnalysisSheet: View {
    @EnvironmentObject var appState: AppState
    let game: ChessGame
    @StateObject private var vm = GameAnalysisViewModel()
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            GameAnalysisView(game: game)
                .navigationTitle("Game Analysis")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { presentationMode.wrappedValue.dismiss() }
                    }
                }
        }
    }
}
