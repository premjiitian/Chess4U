import SwiftUI

struct WeeklyPlanView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let plan = appState.weeklyPlan {
                    // Week summary
                    weekSummary(plan)

                    // Daily plans
                    ForEach(plan.dailyPlans) { day in
                        DailyPlanDetailCard(plan: day)
                    }
                } else {
                    Text("No training plan available.\nComplete your profile to get started.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Weekly Training Plan")
    }

    func weekSummary(_ plan: WeeklyTrainingPlan) -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Week \(plan.weekNumber)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Your Training Plan")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(plan.playerBand.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                Spacer()
                Text(plan.playerBand.icon)
                    .font(.system(size: 44))
            }

            let totalMinutes = plan.dailyPlans.reduce(0) { $0 + $1.estimatedMinutes }
            let completed = plan.dailyPlans.filter { $0.isCompleted }.count

            HStack(spacing: 20) {
                VStack {
                    Text("\(totalMinutes)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Total min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                VStack {
                    Text("\(plan.dailyPlans.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Sessions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                VStack {
                    Text("\(completed)/\(plan.dailyPlans.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("Complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            ProgressView(value: Double(completed), total: Double(plan.dailyPlans.count))
                .tint(.green)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

struct DailyPlanDetailCard: View {
    let plan: DailyPlan
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring()) { isExpanded.toggle() }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(plan.dayOfWeek)
                                .font(.headline)
                            if plan.isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }
                        }
                        Text(plan.focusDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(plan.estimatedMinutes) min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }

            if isExpanded {
                Divider()
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(plan.trainingTypes, id: \.self) { type in
                        HStack {
                            Image(systemName: type.icon)
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(type.rawValue)
                                    .font(.subheadline)
                                Text("\(type.estimatedMinutes) min")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            NavigationLink(destination: TrainingSessionView(trainingType: type)) {
                                Text("Start")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 5)
                                    .background(Color.blue)
                                    .cornerRadius(10)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}
