import SwiftUI

struct TrainingHubView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Coach Alert: pattern-driven suggestion
                    if let profile = appState.playerProfile,
                       let topWeakness = profile.weakestThemes.first {
                        coachAlertBanner(profile: profile, theme: topWeakness)
                    }

                    // Quick Start
                    quickStartSection

                    // Training Types Grid
                    trainingTypesSection

                    // Adaptive Difficulty Status
                    adaptiveStatusSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Training")
        }
        .navigationViewStyle(.stack)
    }

    func trainingTypeForWeakness(_ theme: PuzzleTheme) -> TrainingType {
        switch theme {
        case .fork, .pin, .skewer, .discoveredAttack, .doubleCheck,
             .queenSacrifice, .deflection, .decoy, .xRayAttack, .combination,
             .mateInOne, .mateInTwo, .mateInThree, .backRankMate, .smotheredMate:
            return .tactics
        case .endgameTechnique, .passedPawn, .zugzwang:
            return .endgame
        case .openingTrap:
            return .openings
        case .middlegameTactics:
            return .middlegame
        }
    }

    func coachAlertBanner(profile: PlayerProfile, theme: PuzzleTheme) -> some View {
        let trainingType = trainingTypeForWeakness(theme)
        let attempts  = profile.themeAttempts[theme.rawValue] ?? 0
        let solved    = profile.themeSolved[theme.rawValue] ?? 0
        let pct       = attempts > 0 ? Double(solved) / Double(attempts) : 0.0

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.orange)
                    .font(.headline)
                Text("Coach Alert")
                    .font(.headline)
                    .foregroundColor(.orange)
                Spacer()
                Text("Pattern Detected")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(6)
            }

            HStack(spacing: 14) {
                Text(theme.icon)
                    .font(.title2)
                    .frame(width: 48, height: 48)
                    .background(Color.orange)
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 4) {
                    Text("You're struggling with \(theme.rawValue)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("\(Int(pct * 100))% accuracy over \(attempts) attempts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ProgressView(value: pct)
                        .tint(.orange)
                }

                Spacer()
            }

            NavigationLink(destination: TrainingSessionView(trainingType: trainingType)) {
                HStack {
                    Image(systemName: "bolt.fill")
                    Text("Fix It Now · \(trainingType.rawValue)")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.orange)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.07))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.3), lineWidth: 1))
    }

    var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Quick Start", systemImage: "bolt.fill")
                .font(.headline)
                .foregroundColor(.yellow)

            if let profile = appState.playerProfile {
                let recommended = TreeOfThoughtEngine.shared.selectTrainingPath(
                    for: profile, sessionHistory: []
                )
                NavigationLink(destination: TrainingSessionView(trainingType: recommended)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Continue Training")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(recommended.rawValue + " · \(recommended.estimatedMinutes) min")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        Spacer()
                        Image(systemName: "play.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(LinearGradient(colors: [.blue, .purple],
                                               startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(16)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    var trainingTypesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("All Training Modes", systemImage: "square.grid.2x2")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(TrainingType.allCases, id: \.self) { type in
                    NavigationLink(destination: TrainingSessionView(trainingType: type)) {
                        TrainingTypeCard(type: type)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    var adaptiveStatusSection: some View {
        let adaptive = AdaptiveDifficultyService.shared
        return VStack(alignment: .leading, spacing: 12) {
            Label("Adaptive Engine", systemImage: "brain")
                .font(.headline)

            HStack {
                VStack(alignment: .leading) {
                    Text("Current Level")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(adaptive.currentDifficulty.rawValue)
                        .font(.headline)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Success Rate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(adaptive.successRate * 100))%")
                        .font(.headline)
                        .foregroundColor(adaptive.successRate > 0.7 ? .green : .orange)
                }
            }

            if !adaptive.difficultyMessage.isEmpty {
                Text(adaptive.difficultyMessage)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Training Type Card
struct TrainingTypeCard: View {
    let type: TrainingType

    var cardColor: Color {
        switch type.color {
        case "yellow": return .yellow
        case "blue": return .blue
        case "purple": return .purple
        case "green": return .green
        case "orange": return .orange
        case "teal": return .teal
        case "indigo": return .indigo
        case "red": return .red
        default: return .blue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundColor(cardColor)
                Spacer()
                Text("\(type.estimatedMinutes)m")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(4)
                    .background(Color(.systemGroupedBackground))
                    .cornerRadius(6)
            }

            Text(type.rawValue)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(2)

            Text("Tap to start")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardColor.opacity(0.08))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(cardColor.opacity(0.2)))
    }
}
