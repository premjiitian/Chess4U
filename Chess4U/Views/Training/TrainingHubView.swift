import SwiftUI

struct TrainingHubView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
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
