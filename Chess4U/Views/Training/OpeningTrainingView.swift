import SwiftUI

struct OpeningTrainingView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedOpening: ChessOpening? = nil
    @State private var trainingMode: OpeningTrainingMode = .repertoire

    enum OpeningTrainingMode: String, CaseIterable {
        case repertoire = "My Repertoire"
        case drills = "Variation Drills"
        case test = "Test Mode"
    }

    var filteredOpenings: [ChessOpening] {
        guard appState.playerProfile != nil else { return ChessOpening.openingLibrary }
        return ChessOpening.openingLibrary.filter { opening in
            switch opening.color {
            case .white: return true
            case .black: return true
            case .both: return true
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Mode selector
            Picker("Mode", selection: $trainingMode) {
                ForEach(OpeningTrainingMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            ScrollView {
                VStack(spacing: 14) {
                    switch trainingMode {
                    case .repertoire:
                        repertoireView
                    case .drills:
                        drillsView
                    case .test:
                        testModeView
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
        }
        .navigationTitle("Opening Training")
    }

    var repertoireView: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Player's openings from profile
            if let profile = appState.playerProfile {
                if !profile.mainOpeningsWhite.isEmpty {
                    sectionHeader("Your Openings as White")
                    ForEach(profile.mainOpeningsWhite, id: \.self) { opening in
                        if let match = ChessOpening.openingLibrary.first(where: {
                            $0.name.localizedCaseInsensitiveContains(opening)
                        }) {
                            OpeningCard(opening: match)
                        } else {
                            customOpeningCard(name: opening, color: "White")
                        }
                    }
                }

                if !profile.mainDefensesBlack.isEmpty {
                    sectionHeader("Your Defenses as Black")
                    ForEach(profile.mainDefensesBlack, id: \.self) { defense in
                        if let match = ChessOpening.openingLibrary.first(where: {
                            $0.name.localizedCaseInsensitiveContains(defense)
                        }) {
                            OpeningCard(opening: match)
                        } else {
                            customOpeningCard(name: defense, color: "Black")
                        }
                    }
                }
            }

            sectionHeader("All Openings")
            ForEach(filteredOpenings) { opening in
                OpeningCard(opening: opening)
            }
        }
    }

    var drillsView: some View {
        VStack(spacing: 14) {
            ForEach(filteredOpenings) { opening in
                NavigationLink(destination: VariationPracticeView(opening: opening)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(opening.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("\(opening.variations.count) variations")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.triangle.branch")
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(14)
                }
            }
        }
    }

    var testModeView: some View {
        VStack(spacing: 16) {
            Text("🎯 Test your opening knowledge")
                .font(.headline)

            Text("You'll be shown a position and must play the correct opening moves from memory.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let profile = appState.playerProfile, !profile.mainOpeningsWhite.isEmpty {
                NavigationLink(destination: VariationPracticeView()) {
                    Label("Start Opening Test", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .font(.headline)
                }
            } else {
                Text("Add openings to your profile to enable test mode.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .padding(.top, 4)
    }

    func customOpeningCard(name: String, color: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Custom opening · \(color)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "questionmark.circle")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Opening Card
struct OpeningCard: View {
    let opening: ChessOpening
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring()) { isExpanded.toggle() }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(opening.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(opening.eco)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                        }
                        Text(opening.category.rawValue)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(opening.color.rawValue)
                            .font(.caption2)
                            .padding(4)
                            .background(opening.color == .white ?
                                       Color.yellow.opacity(0.2) : Color.gray.opacity(0.2))
                            .cornerRadius(6)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }

            if isExpanded {
                Divider().padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    Text(opening.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if !opening.typicalPlans.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Key Plans")
                                .font(.caption)
                                .fontWeight(.semibold)
                            ForEach(opening.typicalPlans.prefix(3), id: \.self) { plan in
                                Label(plan, systemImage: "arrow.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        NavigationLink(destination: VariationPracticeView(opening: opening)) {
                            Label("Practice", systemImage: "arrow.triangle.branch")
                                .font(.caption)
                                .padding(8)
                                .frame(maxWidth: .infinity)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(10)
                        }

                        NavigationLink(destination: OpeningDetailView(opening: opening)) {
                            Label("Study", systemImage: "books.vertical")
                                .font(.caption)
                                .padding(8)
                                .frame(maxWidth: .infinity)
                                .background(Color.purple.opacity(0.1))
                                .foregroundColor(.purple)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(14)
    }
}

// MARK: - Opening Detail View
struct OpeningDetailView: View {
    let opening: ChessOpening
    @StateObject private var boardVM = ChessBoardViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Opening board
                ChessBoardView(vm: boardVM, interactive: false)
                    .padding()

                // Description
                VStack(alignment: .leading, spacing: 12) {
                    Text(opening.description)
                        .font(.body)

                    Divider()

                    Group {
                        sectionView("Pawn Structure", opening.pawnStructure)
                        sectionView("Typical Plans", opening.typicalPlans.joined(separator: "\n• "))
                        sectionView("Tactical Motifs", opening.tacticalMotifs.joined(separator: "\n• "))
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .padding(.horizontal)

                // Variations
                VStack(alignment: .leading, spacing: 12) {
                    Text("Main Variations")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(opening.variations) { variation in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(variation.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(variation.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Key Idea: \(variation.keyIdea)")
                                .font(.caption)
                                .foregroundColor(.blue)
                            HStack {
                                ForEach(variation.moves.prefix(6), id: \.self) { move in
                                    Text(move)
                                        .font(.system(.caption, design: .monospaced))
                                        .padding(4)
                                        .background(Color(.systemGroupedBackground))
                                        .cornerRadius(4)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(opening.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if ChessBoard(fen: opening.fen) != nil {
                boardVM.game = ChessGame(fen: opening.fen)
            }
        }
    }

    func sectionView(_ title: String, _ content: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            Text("• " + content)
                .font(.subheadline)
        }
    }
}
