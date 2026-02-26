import SwiftUI

struct LessonDetailView: View {
    let lesson: CourseLesson
    @StateObject private var audioCoach = AudioCoachService.shared
    @State private var currentSection: Int = 0
    @State private var isCompleted: Bool = false
    @State private var showingPractice: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerSection

                // Progress indicator
                HStack {
                    ForEach(lesson.content.indices, id: \.self) { idx in
                        Rectangle()
                            .fill(idx <= currentSection ? Color.blue : Color.gray.opacity(0.3))
                            .frame(height: 3)
                            .cornerRadius(2)
                    }
                }
                .padding(.horizontal)

                // Current section content
                if currentSection < lesson.content.count {
                    let section = lesson.content[currentSection]
                    VStack(alignment: .leading, spacing: 16) {
                        Text(section.heading)
                            .font(.title3)
                            .fontWeight(.bold)

                        Text(section.body)
                            .font(.body)
                            .lineSpacing(6)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    .animation(.easeInOut, value: currentSection)
                }

                // Key takeaway box
                if currentSection < lesson.content.count {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Coach Tip", systemImage: "lightbulb.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        Text(coachTip(for: currentSection))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .background(Color.yellow.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                // Navigation buttons
                navigationButtons

                // Practice section
                if isCompleted {
                    completionSection
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(lesson.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if lesson.hasAudio {
                    Button {
                        if audioCoach.isSpeaking {
                            audioCoach.stop()
                        } else {
                            let text = lesson.content.map { "\($0.heading).\n\($0.body)" }.joined(separator: "\n\n")
                            audioCoach.speak(text)
                        }
                    } label: {
                        Image(systemName: audioCoach.isSpeaking ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .onDisappear {
            audioCoach.stop()
        }
    }

    var headerSection: some View {
        HStack(spacing: 14) {
            Image(systemName: lesson.icon)
                .font(.largeTitle)
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(lesson.categoryColor)
                .cornerRadius(16)

            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.title)
                    .font(.headline)
                Text(lesson.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                HStack(spacing: 10) {
                    Label(lesson.duration, systemImage: "clock")
                    Text("·")
                    Text(lesson.difficulty)
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    var navigationButtons: some View {
        HStack(spacing: 16) {
            if currentSection > 0 {
                Button {
                    withAnimation { currentSection -= 1 }
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3)))
                }
            }

            if currentSection < lesson.content.count - 1 {
                Button {
                    withAnimation { currentSection += 1 }
                } label: {
                    HStack {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            } else if !isCompleted {
                Button {
                    withAnimation { isCompleted = true }
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Complete Lesson")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
        }
        .padding(.horizontal)
        .font(.subheadline)
        .fontWeight(.medium)
    }

    var completionSection: some View {
        VStack(spacing: 16) {
            Text("🎉 Lesson Complete!")
                .font(.title2)
                .fontWeight(.bold)

            Text("Well done! You've studied \(lesson.title). Now reinforce your learning with practice.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            NavigationLink(destination: TrainingSessionView(trainingType: trainingTypeForCategory)) {
                Label("Practice Now", systemImage: "bolt.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .font(.headline)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    var trainingTypeForCategory: TrainingType {
        switch lesson.category {
        case "Tactics": return .tactics
        case "Openings": return .openings
        case "Endgames": return .endgame
        case "Strategy": return .middlegame
        case "Calculation": return .calculation
        default: return .tactics
        }
    }

    func coachTip(for section: Int) -> String {
        let tips = [
            "Remember: understanding is more valuable than memorization in chess.",
            "Apply this concept in your next game. Look for opportunities actively.",
            "The best players don't just know the theory — they feel it intuitively.",
            "Practice this position type in your training sessions to build intuition.",
        ]
        return tips[section % tips.count]
    }
}
