import SwiftUI

struct FreePlayView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = ChessBoardViewModel()
    @State private var showingAnalysis = false
    @State private var vsMode: VsMode = .vsAI
    @State private var aiDepth: Int = 3

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

                // Chess board
                VStack {
                    if vsMode == .twoPlayer || vm.game.board.activeColor == .white {
                        ChessBoardView(vm: vm, interactive: true)
                            .padding()
                    } else {
                        ChessBoardView(vm: vm, interactive: false)
                            .padding()
                    }
                }
                .onChange(of: vm.game.moves.count) { _ in
                    if vsMode == .vsAI && vm.game.board.activeColor == .black {
                        vm.makeAIMove(depth: aiDepth)
                    }
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
            .sheet(isPresented: $showingAnalysis) {
                GameAnalysisSheet(game: vm.game)
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            vm.settings = appState.settings
            vm.profile = appState.playerProfile
        }
    }

    var statusBar: some View {
        HStack {
            Circle()
                .fill(vm.game.board.activeColor == .white ? Color.white : Color.black)
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(Color.gray, lineWidth: 1))

            Text(vm.statusMessage)
                .font(.subheadline)
                .foregroundColor(.primary)

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

            Button { newGame() } label: {
                Image(systemName: "plus.circle")
            }

            Spacer()

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
