import SwiftUI

struct PlayerAssessmentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.presentationMode) var presentationMode

    @State private var playerName: String = ""
    @State private var eloString: String = "1200"
    @State private var timeControl: TimeControl = .rapid
    @State private var playerType: PlayerType = .casual
    @State private var ratingTrend: RatingTrend = .stable
    @State private var selectedWeaknesses: Set<WeaknessArea> = []
    @State private var mainOpeningsWhite: String = ""
    @State private var mainDefensesBlack: String = ""
    @State private var currentStep: Int = 0
    @State private var showingCompletion: Bool = false

    private let steps = ["Basic Info", "Play Style", "Weaknesses", "Openings"]
    private var elo: Int { Int(eloString) ?? 1200 }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress bar
                VStack(spacing: 8) {
                    HStack {
                        ForEach(steps.indices, id: \.self) { idx in
                            Rectangle()
                                .fill(idx <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                                .frame(height: 4)
                                .cornerRadius(2)
                                .animation(.easeInOut, value: currentStep)
                        }
                    }
                    Text("Step \(currentStep + 1) of \(steps.count): \(steps[currentStep])")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()

                ScrollView {
                    VStack(spacing: 20) {
                        switch currentStep {
                        case 0: basicInfoStep
                        case 1: playStyleStep
                        case 2: weaknessesStep
                        case 3: openingsStep
                        default: EmptyView()
                        }
                    }
                    .padding()
                }

                // Navigation buttons
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation { currentStep -= 1 }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue))
                    }

                    Button(currentStep == steps.count - 1 ? "Start Training!" : "Continue") {
                        if currentStep == steps.count - 1 {
                            createProfile()
                        } else {
                            withAnimation { currentStep += 1 }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isCurrentStepValid ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(!isCurrentStepValid)
                    .font(.headline)
                }
                .padding()
            }
        }
        .navigationTitle("Player Assessment")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Step Views
    var basicInfoStep: some View {
        VStack(spacing: 20) {
            AssessmentCard(title: "What's your name?", icon: "person") {
                TextField("Your name", text: $playerName)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
            }

            AssessmentCard(title: "Current Elo Rating", icon: "speedometer") {
                VStack(spacing: 8) {
                    TextField("e.g. 1200", text: $eloString)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)

                    if let eloVal = Int(eloString) {
                        let band = PlayerBand.band(for: eloVal)
                        HStack {
                            Text(band.icon)
                            Text(band.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }

            AssessmentCard(title: "Preferred Time Control", icon: "clock") {
                Picker("Time Control", selection: $timeControl) {
                    ForEach(TimeControl.allCases, id: \.self) { tc in
                        Text(tc.rawValue).tag(tc)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    var playStyleStep: some View {
        VStack(spacing: 20) {
            AssessmentCard(title: "Player Type", icon: "person.2") {
                Picker("Player Type", selection: $playerType) {
                    ForEach(PlayerType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }

            AssessmentCard(title: "Recent Rating Trend", icon: "chart.line.uptrend.xyaxis") {
                VStack(spacing: 12) {
                    ForEach(RatingTrend.allCases, id: \.self) { trend in
                        Button {
                            ratingTrend = trend
                        } label: {
                            HStack {
                                Image(systemName: ratingTrend == trend ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(ratingTrend == trend ? .blue : .gray)
                                Text(trend.rawValue)
                                    .foregroundColor(.primary)
                                Spacer()
                                trendIcon(trend)
                            }
                            .padding(12)
                            .background(ratingTrend == trend ? Color.blue.opacity(0.1) : Color(.systemBackground))
                            .cornerRadius(10)
                        }
                    }
                }
            }
        }
    }

    var weaknessesStep: some View {
        AssessmentCard(title: "Main Weaknesses", icon: "exclamationmark.triangle") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Select up to 3 areas to focus on:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(WeaknessArea.allCases, id: \.self) { weakness in
                        Button {
                            if selectedWeaknesses.contains(weakness) {
                                selectedWeaknesses.remove(weakness)
                            } else if selectedWeaknesses.count < 3 {
                                selectedWeaknesses.insert(weakness)
                            }
                        } label: {
                            HStack {
                                Image(systemName: weakness.icon)
                                    .font(.caption)
                                Text(weakness.rawValue)
                                    .font(.caption)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(selectedWeaknesses.contains(weakness) ?
                                       Color.red.opacity(0.2) : Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selectedWeaknesses.contains(weakness) ? Color.red : Color.gray.opacity(0.3))
                            )
                            .cornerRadius(10)
                            .foregroundColor(selectedWeaknesses.contains(weakness) ? .red : .primary)
                        }
                    }
                }
            }
        }
    }

    var openingsStep: some View {
        VStack(spacing: 20) {
            AssessmentCard(title: "Main Openings as White", icon: "arrow.up.circle") {
                TextField("e.g. e4, Italian Game, Ruy Lopez", text: $mainOpeningsWhite)
                    .textFieldStyle(.roundedBorder)
            }

            AssessmentCard(title: "Main Defenses as Black", icon: "arrow.down.circle") {
                TextField("e.g. Sicilian, King's Indian, French", text: $mainDefensesBlack)
                    .textFieldStyle(.roundedBorder)
            }

            // Band summary
            let band = PlayerBand.band(for: elo)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(band.icon)
                        .font(.title)
                    VStack(alignment: .leading) {
                        Text("Your Training Band")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(band.rawValue)
                            .font(.headline)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)

                Text("Your Focus Areas:")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                ForEach(band.focusAreas, id: \.self) { area in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text(area)
                            .font(.subheadline)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
        }
    }

    // MARK: - Helpers
    var isCurrentStepValid: Bool {
        switch currentStep {
        case 0: return !playerName.isEmpty && Int(eloString) != nil
        case 1: return true
        case 2: return !selectedWeaknesses.isEmpty
        case 3: return true
        default: return false
        }
    }

    func trendIcon(_ trend: RatingTrend) -> some View {
        switch trend {
        case .improving: return Image(systemName: "arrow.up.right").foregroundColor(.green)
        case .stable:    return Image(systemName: "arrow.right").foregroundColor(.blue)
        case .declining: return Image(systemName: "arrow.down.right").foregroundColor(.red)
        }
    }

    func createProfile() {
        let openingsWhite = mainOpeningsWhite.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let defensesBlack = mainDefensesBlack.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        var profile = PlayerProfile(
            name: playerName.isEmpty ? "Player" : playerName,
            elo: elo,
            preferredTimeControl: timeControl,
            playerType: playerType,
            mainOpeningsWhite: openingsWhite,
            mainDefensesBlack: defensesBlack,
            ratingTrend: ratingTrend,
            weaknesses: Array(selectedWeaknesses)
        )
        profile.tacticsAccuracy = 50.0
        profile.openingAccuracy = 50.0
        profile.endgameAccuracy = 50.0
        profile.calculationScore = 50.0
        profile.strategyScore = 50.0

        appState.savePlayerProfile(profile)
    }
}

// MARK: - Assessment Card
struct AssessmentCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
            }
            content
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
