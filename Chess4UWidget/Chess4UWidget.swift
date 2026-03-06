import WidgetKit
import SwiftUI

// MARK: - Shared Data Keys
// Must match keys in PersistenceService.sharedDefaults
private enum WidgetKey {
    static let streak      = "chess4u.streak"
    static let playerName  = "chess4u.playerName"
    static let elo         = "chess4u.elo"
    static let todayDone   = "chess4u.todaySessionsDone"
    static let todayGoal   = "chess4u.todaySessionsGoal"
    static let lastDate    = "chess4u.lastSessionDate"
}

private let appGroup = "group.com.chess4u.app"

// MARK: - Widget Entry

struct StreakEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let playerName: String
    let elo: Int
    let todayDone: Int
    let todayGoal: Int
    let isActiveToday: Bool

    static var placeholder: StreakEntry {
        StreakEntry(date: .now, streak: 7, playerName: "Alex",
                   elo: 1450, todayDone: 1, todayGoal: 3, isActiveToday: true)
    }
}

// MARK: - Timeline Provider

struct StreakProvider: TimelineProvider {
    private var shared: UserDefaults? { UserDefaults(suiteName: appGroup) }

    func placeholder(in context: Context) -> StreakEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(context.isPreview ? .placeholder : makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let entry = makeEntry()
        // Refresh at the start of every hour so streak auto-resets at midnight
        let nextUpdate = Calendar.current.nextDate(
            after: .now,
            matching: DateComponents(minute: 0),
            matchingPolicy: .nextTime
        ) ?? Date(timeIntervalSinceNow: 3600)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> StreakEntry {
        let d = shared ?? .standard
        let lastDate = d.object(forKey: WidgetKey.lastDate) as? Date
        let isToday = lastDate.map { Calendar.current.isDateInToday($0) } ?? false
        return StreakEntry(
            date: .now,
            streak: d.integer(forKey: WidgetKey.streak),
            playerName: d.string(forKey: WidgetKey.playerName) ?? "Player",
            elo: d.integer(forKey: WidgetKey.elo),
            todayDone: isToday ? d.integer(forKey: WidgetKey.todayDone) : 0,
            todayGoal: max(1, d.integer(forKey: WidgetKey.todayGoal)),
            isActiveToday: isToday
        )
    }
}

// MARK: - Small Widget View

struct SmallStreakView: View {
    let entry: StreakEntry

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(Color(.systemBackground))

            VStack(spacing: 6) {
                Text("🔥")
                    .font(.system(size: 36))

                Text("\(entry.streak)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(entry.streak > 0 ? .orange : .secondary)

                Text(entry.streak == 1 ? "day streak" : "day streak")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if entry.isActiveToday {
                    Label("Today done", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                } else {
                    Text("Train today!")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .fontWeight(.semibold)
                }
            }
            .padding(8)
        }
    }
}

// MARK: - Medium Widget View

struct MediumStreakView: View {
    let entry: StreakEntry

    private var progress: Double {
        guard entry.todayGoal > 0 else { return 0 }
        return min(1.0, Double(entry.todayDone) / Double(entry.todayGoal))
    }

    var body: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(Color(.systemBackground))

            HStack(spacing: 16) {
                // Left: streak
                VStack(spacing: 4) {
                    Text("🔥")
                        .font(.system(size: 30))
                    Text("\(entry.streak)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(entry.streak > 0 ? .orange : .secondary)
                    Text("day\nstreak")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: 80)

                Divider()

                // Right: today's plan + player info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.playerName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Elo \(entry.elo)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Today")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(entry.todayDone)/\(entry.todayGoal)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(entry.isActiveToday ? .green : .primary)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(entry.isActiveToday ? Color.green : Color.blue)
                                    .frame(width: geo.size.width * progress, height: 6)
                            }
                        }
                        .frame(height: 6)
                    }

                    if entry.isActiveToday && entry.todayDone >= entry.todayGoal {
                        Label("Goal complete!", systemImage: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    } else if !entry.isActiveToday {
                        Label("Open app to train", systemImage: "bolt.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.trailing, 4)
            }
            .padding(12)
        }
    }
}

// MARK: - Widget Entry View (size router)

struct Chess4UWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: StreakEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallStreakView(entry: entry)
        default:
            MediumStreakView(entry: entry)
        }
    }
}

// MARK: - Widget Definition

struct Chess4UStreakWidget: Widget {
    let kind = "Chess4UStreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            Chess4UWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Training Streak")
        .description("Keep track of your daily chess training streak and today's progress.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct Chess4UWidgetBundle: WidgetBundle {
    var body: some Widget {
        Chess4UStreakWidget()
    }
}
