import SwiftUI

struct LessonLibraryView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedCategory: LessonCategory = .all
    @State private var searchText: String = ""

    enum LessonCategory: String, CaseIterable {
        case all = "All"
        case tactics = "Tactics"
        case openings = "Openings"
        case endgames = "Endgames"
        case strategy = "Strategy"
        case calculation = "Calculation"
    }

    var filteredLessons: [CourseLesson] {
        var lessons = CourseLesson.allLessons
        if selectedCategory != .all {
            lessons = lessons.filter { $0.category == selectedCategory.rawValue }
        }
        if !searchText.isEmpty {
            lessons = lessons.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        if let profile = appState.playerProfile {
            lessons = lessons.filter {
                $0.minElo <= profile.elo + 200
            }
        }
        return lessons
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(LessonCategory.allCases, id: \.self) { cat in
                            Button {
                                selectedCategory = cat
                            } label: {
                                Text(cat.rawValue)
                                    .font(.subheadline)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(selectedCategory == cat ? Color.blue : Color(.systemGroupedBackground))
                                    .foregroundColor(selectedCategory == cat ? .white : .primary)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }

                // Lesson list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Featured courses
                        if selectedCategory == .all && searchText.isEmpty {
                            FeaturedCoursesSection()
                        }

                        ForEach(filteredLessons) { lesson in
                            NavigationLink(destination: LessonDetailView(lesson: lesson)) {
                                LessonCard(lesson: lesson)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
            }
            .navigationTitle("Lessons")
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Featured Courses Section
struct FeaturedCoursesSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Featured Courses")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(FeaturedCourse.courses) { course in
                        FeaturedCourseCard(course: course)
                    }
                }
            }
        }
    }
}

struct FeaturedCourse: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let lessonCount: Int

    static let courses: [FeaturedCourse] = [
        FeaturedCourse(title: "Opening Mastery", subtitle: "Build a solid repertoire", icon: "book.fill", color: .blue, lessonCount: 12),
        FeaturedCourse(title: "Tactics Accelerator", subtitle: "Pattern recognition training", icon: "bolt.fill", color: .yellow, lessonCount: 20),
        FeaturedCourse(title: "Endgame Technique", subtitle: "Win winning positions", icon: "flag.checkered", color: .green, lessonCount: 15),
        FeaturedCourse(title: "Calculation Bootcamp", subtitle: "Think deeper, play better", icon: "brain", color: .purple, lessonCount: 10),
    ]
}

struct FeaturedCourseCard: View {
    let course: FeaturedCourse

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: course.icon)
                .font(.title)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(course.color)
                .cornerRadius(12)

            Text(course.title)
                .font(.headline)
                .foregroundColor(.primary)

            Text(course.subtitle)
                .font(.caption)
                .foregroundColor(.secondary)

            Text("\(course.lessonCount) lessons")
                .font(.caption2)
                .foregroundColor(course.color)
        }
        .padding()
        .frame(width: 160)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

// MARK: - Lesson Card
struct LessonCard: View {
    let lesson: CourseLesson

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: lesson.icon)
                .font(.title2)
                .foregroundColor(lesson.categoryColor)
                .frame(width: 48, height: 48)
                .background(lesson.categoryColor.opacity(0.1))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(lesson.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Spacer()
                    if lesson.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }

                Text(lesson.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label(lesson.duration, systemImage: "clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(lesson.difficulty)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if lesson.hasAudio {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(14)
    }
}

// MARK: - Course Lesson Model
struct CourseLesson: Identifiable {
    let id = UUID()
    var title: String
    var description: String
    var category: String
    var icon: String
    var duration: String
    var difficulty: String
    var hasAudio: Bool
    var isCompleted: Bool = false
    var minElo: Int
    var content: [LessonSection]

    var categoryColor: Color {
        switch category {
        case "Tactics": return .yellow
        case "Openings": return .blue
        case "Endgames": return .green
        case "Strategy": return .purple
        case "Calculation": return .orange
        default: return .gray
        }
    }

    static let allLessons: [CourseLesson] = [
        CourseLesson(title: "The Art of the Fork", description: "Learn to create powerful double attacks with knights and other pieces.", category: "Tactics", icon: "bolt.fill", duration: "15 min", difficulty: "Beginner", hasAudio: true, minElo: 800, content: [
            LessonSection(heading: "What is a Fork?", body: "A fork is a tactic where one piece attacks two or more enemy pieces simultaneously. The knight is the best forking piece because it moves in an L-shape and is hard to defend against."),
            LessonSection(heading: "Knight Fork Pattern", body: "Look for positions where your knight can jump to a square that attacks the king AND another valuable piece. The opponent can only move one piece, so you win the other."),
            LessonSection(heading: "Practice", body: "In the following positions, find the knight fork. Remember to check all possible knight destinations!")
        ]),
        CourseLesson(title: "Pins and How to Use Them", description: "Master the pin — one of chess's most powerful positional weapons.", category: "Tactics", icon: "pin.fill", duration: "20 min", difficulty: "Beginner", hasAudio: true, minElo: 900, content: [
            LessonSection(heading: "What is a Pin?", body: "A pin is when a piece cannot move because it would expose a more valuable piece behind it to capture. The pinning piece 'nails' the pinned piece in place."),
            LessonSection(heading: "Absolute vs. Relative Pin", body: "An absolute pin is when the piece behind is the king — the pinned piece literally cannot move. A relative pin is when the piece behind is valuable but not the king."),
            LessonSection(heading: "Exploiting Pins", body: "Once you have pinned a piece, attack it with more pieces than your opponent can defend it with. Eventually the pinned piece falls!")
        ]),
        CourseLesson(title: "Opening Principles", description: "The fundamental rules every chess player needs to know for the opening.", category: "Openings", icon: "book.fill", duration: "25 min", difficulty: "Beginner", hasAudio: true, minElo: 800, content: [
            LessonSection(heading: "Rule 1: Control the Center", body: "The four central squares (e4, e5, d4, d5) are the most important squares on the board. Your opening moves should fight for these squares with pawns and pieces."),
            LessonSection(heading: "Rule 2: Develop Your Pieces", body: "Move each piece only once in the opening. Get your knights and bishops out quickly. Don't waste time with pawn moves on the wings when your pieces aren't developed."),
            LessonSection(heading: "Rule 3: Castle Early", body: "Castling puts your king into safety and connects your rooks. Try to castle within the first 10 moves. Don't delay castling unnecessarily.")
        ]),
        CourseLesson(title: "Rook Endgames", description: "Learn the key principles for winning and drawing rook endgames.", category: "Endgames", icon: "flag.checkered", duration: "30 min", difficulty: "Intermediate", hasAudio: true, minElo: 1200, content: [
            LessonSection(heading: "The Principle of Activity", body: "In rook endgames, the most important factor is the activity of your rook. A passive rook loses. Always find the most active square for your rook."),
            LessonSection(heading: "Rook Behind the Passed Pawn", body: "Place your rook behind a passed pawn, not in front of it. Behind a passed pawn, the rook gains power as the pawn advances. In front, the rook is blocked."),
            LessonSection(heading: "The Philidor Position", body: "This is the key defensive technique in rook endgames. Place your rook on the 6th rank (3rd rank if defending as Black) to cut off the enemy king.")
        ]),
        CourseLesson(title: "Calculation Training", description: "Systematic method to calculate chess positions deeply and accurately.", category: "Calculation", icon: "brain", duration: "35 min", difficulty: "Advanced", hasAudio: true, minElo: 1400, content: [
            LessonSection(heading: "Step 1: Identify Candidate Moves", body: "Don't calculate randomly! First, make a list of candidate moves — the moves worth calculating. Look for: checks, captures, and threats."),
            LessonSection(heading: "Step 2: Calculate Forcing Lines First", body: "Calculate the most forcing moves first. Checks force the opponent to respond. Captures create concrete tactical situations that can be calculated precisely."),
            LessonSection(heading: "Step 3: Evaluate the Position", body: "After calculating a line to a quiet position, evaluate: material, king safety, pawn structure, piece activity. Choose the move that leads to the best evaluation.")
        ]),
        CourseLesson(title: "Positional Chess — Weak Squares", description: "Understand how to identify and exploit weak squares in the position.", category: "Strategy", icon: "map.fill", duration: "25 min", difficulty: "Intermediate", hasAudio: false, minElo: 1300, content: [
            LessonSection(heading: "What is a Weak Square?", body: "A square that cannot be defended by pawns is potentially weak. If your opponent can occupy such a square with a piece, especially a knight, the square becomes a powerful outpost."),
            LessonSection(heading: "Creating and Using Outposts", body: "An outpost is a strong square your piece can occupy without being driven away by enemy pawns. A knight on d5 or e5 in the center is often decisive."),
            LessonSection(heading: "Prophylaxis", body: "Before improving your position, prevent your opponent's improvements. Think about what your opponent wants to do and stop it before attacking.")
        ]),
        CourseLesson(title: "Italian Game Deep Dive", description: "Complete study of the Italian Game: ideas, plans, and key variations.", category: "Openings", icon: "book.closed.fill", duration: "40 min", difficulty: "Intermediate", hasAudio: true, minElo: 1100, content: [
            LessonSection(heading: "The Idea", body: "White develops the bishop to c4, targeting the weak f7 pawn and fighting for central control. It's one of the oldest openings but remains highly relevant at all levels."),
            LessonSection(heading: "Main Variations", body: "The Giuoco Piano (3...Bc5) leads to rich strategic play. The Two Knights (3...Nf6) leads to sharp tactical battles. The Giuoco Pianissimo (4.c3 Nf6 5.d3) is the modern approach."),
            LessonSection(heading: "White's Plans", body: "White typically plays c3 and d4 to establish a pawn center, then launches a kingside attack with Ng5 or prepares f4-f5. The f7 pawn is always a target.")
        ]),
        CourseLesson(title: "Endgame Fundamentals — King & Pawn", description: "Master the most fundamental endgame: King and Pawn versus King.", category: "Endgames", icon: "crown", duration: "20 min", difficulty: "Beginner", hasAudio: true, minElo: 800, content: [
            LessonSection(heading: "The Opposition", body: "When two kings face each other with one square between them, the player who has to move is said to be in 'opposition.' The player who has the opposition has the advantage."),
            LessonSection(heading: "Key Squares", body: "For each pawn, there are specific 'key squares' that the king must reach to guarantee promotion. For a central pawn on e4, the key squares are d6, e6, and f6."),
            LessonSection(heading: "The Rule of the Square", body: "To determine if a king can catch a passed pawn: draw a square from the pawn to the promotion square. If the king can enter this square, it catches the pawn.")
        ])
    ]
}

struct LessonSection: Identifiable {
    let id = UUID()
    var heading: String
    var body: String
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search lessons...", text: $text)
        }
        .padding(10)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}
