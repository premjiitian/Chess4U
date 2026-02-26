import SwiftUI

struct AchievementsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedCategory: AchievementCategory? = nil

    var filteredAchievements: [Achievement] {
        let all = Achievement.allAchievements
        let earned = Set(appState.achievements.map { $0.id })

        var result: [Achievement] = []
        for a in all {
            var ach = a
            if earned.contains(a.id) {
                ach.earnedDate = appState.achievements.first(where: { $0.id == a.id })?.earnedDate ?? Date()
            }
            result.append(ach)
        }

        if let cat = selectedCategory {
            return result.filter { $0.category == cat }
        }
        return result
    }

    var earnedCount: Int { appState.achievements.count }
    var totalCount: Int { Achievement.allAchievements.count }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Progress header
                progressHeader

                // Category filter
                categoryFilter

                // Achievement grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(filteredAchievements) { achievement in
                        AchievementDetailCard(achievement: achievement)
                    }
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Achievements")
    }

    var progressHeader: some View {
        VStack(spacing: 12) {
            Text("🏆 \(earnedCount)/\(totalCount)")
                .font(.largeTitle)
                .fontWeight(.bold)

            ProgressView(value: Double(earnedCount), total: Double(totalCount))
                .tint(.yellow)
                .padding(.horizontal)

            Text("\(totalCount - earnedCount) achievements remaining")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding()
    }

    var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Button {
                    selectedCategory = nil
                } label: {
                    Text("All")
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(selectedCategory == nil ? Color.blue : Color(.systemBackground))
                        .foregroundColor(selectedCategory == nil ? .white : .primary)
                        .cornerRadius(20)
                }

                ForEach(AchievementCategory.allCases, id: \.self) { cat in
                    Button {
                        selectedCategory = selectedCategory == cat ? nil : cat
                    } label: {
                        Text(cat.rawValue)
                            .font(.subheadline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(selectedCategory == cat ? Color.blue : Color(.systemBackground))
                            .foregroundColor(selectedCategory == cat ? .white : .primary)
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct AchievementDetailCard: View {
    let achievement: Achievement

    var rarityColor: Color {
        switch achievement.rarity {
        case .common:    return .gray
        case .uncommon:  return .green
        case .rare:      return .blue
        case .epic:      return .purple
        case .legendary: return .orange
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(achievement.isEarned ? rarityColor.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 60, height: 60)

                Image(systemName: achievement.icon)
                    .font(.title2)
                    .foregroundColor(achievement.isEarned ? rarityColor : .gray)
            }

            Text(achievement.title)
                .font(.caption)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Text(achievement.description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text(achievement.rarity.rawValue)
                .font(.caption2)
                .foregroundColor(rarityColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(rarityColor.opacity(0.1))
                .cornerRadius(8)

            if let date = achievement.earnedDate {
                Text(date, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Text("Locked")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .opacity(achievement.isEarned ? 1.0 : 0.6)
    }
}
