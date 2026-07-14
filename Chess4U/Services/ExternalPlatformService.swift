import Foundation

// MARK: - External Game Model
struct ExternalGame: Identifiable {
    let id: String
    let pgn: String
    let platform: Platform
    let whitePlayer: String
    let blackPlayer: String
    let result: String
    let timeControl: String
    let endTime: Date
    /// Both players' ratings at the time the game was played, when the
    /// platform's API reports them -- shown on puzzles generated from this
    /// game so the player has context on the strength of the opposition.
    var whiteRating: Int? = nil
    var blackRating: Int? = nil

    enum Platform: String {
        case chesscom = "chess.com"
        case lichess = "Lichess"
    }
}

// MARK: - External Platform Service
/// Fetches games from chess.com and Lichess via their public REST APIs.
/// No authentication is required — only public usernames are needed.
final class ExternalPlatformService: ObservableObject {
    static let shared = ExternalPlatformService()

    @Published var isFetching: Bool = false
    @Published var lastError: String?
    @Published var recentGames: [ExternalGame] = []

    private init() {}

    // MARK: - Chess.com API
    /// Fetches up to `maxGames` of the most recent monthly-archive games for a chess.com user.
    func fetchChesscomGames(username: String, maxGames: Int = 20) async throws -> [ExternalGame] {
        let archives = try await fetchChesscomArchiveURLs(username: username)
        guard let latestArchiveURLStr = archives.last,
              let latestURL = URL(string: latestArchiveURLStr) else {
            return []
        }
        let games = try await fetchChesscomGames(archiveURL: latestURL)
        return Array(games.suffix(maxGames))
    }

    /// Fetches every chess.com game played in the last `days` days. Chess.com's
    /// API is organized into one archive per calendar month, so a 30-day
    /// window can span two archives (e.g. requested on the 3rd of a month) --
    /// we walk back from the most recent archive until we pass the cutoff.
    func fetchChesscomGames(username: String, sinceDaysAgo days: Int) async throws -> [ExternalGame] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date.distantPast
        let archives = try await fetchChesscomArchiveURLs(username: username)

        var collected: [ExternalGame] = []
        // Walk archives newest-first; stop once an entire archive is older than the cutoff.
        for archiveURLStr in archives.reversed() {
            guard let url = URL(string: archiveURLStr) else { continue }
            let games = try await fetchChesscomGames(archiveURL: url)
            let inRange = games.filter { $0.endTime >= cutoff }
            collected.append(contentsOf: inRange)
            // If nothing in this archive was recent enough, earlier archives won't be either.
            if inRange.isEmpty && !games.isEmpty { break }
        }
        return collected.sorted { $0.endTime < $1.endTime }
    }

    private func fetchChesscomArchiveURLs(username: String) async throws -> [String] {
        let archivesURL = URL(string: "https://api.chess.com/pub/player/\(username.lowercased())/games/archives")!
        let (archivesData, _) = try await URLSession.shared.data(from: archivesURL)
        struct Archives: Decodable { let archives: [String] }
        return try JSONDecoder().decode(Archives.self, from: archivesData).archives
    }

    private func fetchChesscomGames(archiveURL: URL) async throws -> [ExternalGame] {
        let (gamesData, _) = try await URLSession.shared.data(from: archiveURL)

        struct ChesscomGame: Decodable {
            let pgn: String?
            let white: Player
            let black: Player
            let end_time: Int
            let time_control: String
            struct Player: Decodable { let username: String; let result: String; let rating: Int? }
        }
        struct ChesscomResponse: Decodable { let games: [ChesscomGame] }

        let response = try JSONDecoder().decode(ChesscomResponse.self, from: gamesData)
        return response.games.compactMap { g -> ExternalGame? in
            guard let pgn = g.pgn, !pgn.isEmpty else { return nil }
            return ExternalGame(
                id: "\(g.end_time)-\(g.white.username)-\(g.black.username)",
                pgn: pgn,
                platform: .chesscom,
                whitePlayer: g.white.username,
                blackPlayer: g.black.username,
                result: g.white.result == "win" ? "1-0" : g.black.result == "win" ? "0-1" : "1/2-1/2",
                timeControl: g.time_control,
                endTime: Date(timeIntervalSince1970: TimeInterval(g.end_time)),
                whiteRating: g.white.rating,
                blackRating: g.black.rating
            )
        }
    }

    // MARK: - Lichess API
    /// Fetches the most recent `maxGames` games for a Lichess user (exported as PGN).
    /// When `sinceDaysAgo` is provided, only games from that window are requested
    /// (Lichess supports this natively via the `since` query parameter, in ms).
    func fetchLichessGames(username: String, maxGames: Int = 20, sinceDaysAgo: Int? = nil) async throws -> [ExternalGame] {
        var components = URLComponents(string: "https://lichess.org/api/games/user/\(username.lowercased())")!
        var queryItems = [
            URLQueryItem(name: "max", value: "\(maxGames)"),
            URLQueryItem(name: "pgnInJson", value: "true"),
            URLQueryItem(name: "clocks", value: "false"),
            URLQueryItem(name: "evals", value: "false")
        ]
        if let days = sinceDaysAgo {
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date.distantPast
            let sinceMs = Int(cutoff.timeIntervalSince1970 * 1000)
            queryItems.append(URLQueryItem(name: "since", value: "\(sinceMs)"))
        }
        components.queryItems = queryItems
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        // Lichess requires Accept: application/x-ndjson for JSON-per-line format
        request.setValue("application/x-ndjson", forHTTPHeaderField: "Accept")

        let (data, _) = try await URLSession.shared.data(for: request)
        let lines = String(data: data, encoding: .utf8)?
            .split(separator: "\n", omittingEmptySubsequences: true) ?? []

        struct LichessGame: Decodable {
            let id: String
            let pgn: String?
            let players: Players
            let winner: String?
            let clock: Clock?
            struct Players: Decodable {
                let white: Player
                let black: Player
                struct Player: Decodable { let user: User?; let rating: Int? }
                struct User: Decodable { let name: String }
            }
            struct Clock: Decodable { let initial: Int; let increment: Int }
        }

        var games: [ExternalGame] = []
        for line in lines {
            guard let lineData = line.data(using: .utf8),
                  let game = try? JSONDecoder().decode(LichessGame.self, from: lineData),
                  let pgn = game.pgn, !pgn.isEmpty else { continue }

            let white = game.players.white.user?.name ?? "White"
            let black = game.players.black.user?.name ?? "Black"
            let result: String
            switch game.winner {
            case "white": result = "1-0"
            case "black": result = "0-1"
            default:      result = "1/2-1/2"
            }
            let tc = game.clock.map { "\($0.initial/60)+\($0.increment)" } ?? "?"

            games.append(ExternalGame(
                id: game.id,
                pgn: pgn,
                platform: .lichess,
                whitePlayer: white,
                blackPlayer: black,
                result: result,
                timeControl: tc,
                endTime: Date(),
                whiteRating: game.players.white.rating,
                blackRating: game.players.black.rating
            ))
        }
        return games
    }

    // MARK: - Quick Profile Lookup (onboarding "Connect" flow)
    /// Looks up a public chess.com/Lichess account by username and returns a
    /// best-effort current rating + display name, using only public,
    /// unauthenticated endpoints. Used by onboarding's "Connect chess.com or
    /// Lichess" quick-start path so a new profile can start from the
    /// player's real rating instead of a guess.
    struct QuickProfile {
        let username: String
        let displayName: String?
        let rating: Int?
    }

    func fetchQuickProfile(platform: ExternalGame.Platform, username: String) async throws -> QuickProfile {
        switch platform {
        case .chesscom:
            return try await fetchChesscomQuickProfile(username: username)
        case .lichess:
            return try await fetchLichessQuickProfile(username: username)
        }
    }

    private func fetchChesscomQuickProfile(username: String) async throws -> QuickProfile {
        let clean = username.lowercased()
        // Public profile endpoint (name, no auth needed).
        struct Profile: Decodable { let name: String? }
        var displayName: String? = nil
        if let profileURL = URL(string: "https://api.chess.com/pub/player/\(clean)") {
            if let (data, _) = try? await URLSession.shared.data(from: profileURL),
               let profile = try? JSONDecoder().decode(Profile.self, from: data) {
                displayName = profile.name
            }
        }
        // Stats endpoint has per-format ratings; use rapid, falling back to blitz/bullet.
        struct Stats: Decodable {
            let chess_rapid: Rating?
            let chess_blitz: Rating?
            let chess_bullet: Rating?
            struct Rating: Decodable { let last: Last?; struct Last: Decodable { let rating: Int } }
        }
        guard let statsURL = URL(string: "https://api.chess.com/pub/player/\(clean)/stats") else {
            return QuickProfile(username: username, displayName: displayName, rating: nil)
        }
        let (data, _) = try await URLSession.shared.data(from: statsURL)
        let stats = try JSONDecoder().decode(Stats.self, from: data)
        let rating = stats.chess_rapid?.last?.rating ?? stats.chess_blitz?.last?.rating ?? stats.chess_bullet?.last?.rating
        return QuickProfile(username: username, displayName: displayName, rating: rating)
    }

    private func fetchLichessQuickProfile(username: String) async throws -> QuickProfile {
        guard let url = URL(string: "https://lichess.org/api/user/\(username.lowercased())") else {
            throw URLError(.badURL)
        }
        struct LichessUser: Decodable {
            let username: String?
            let perfs: Perfs?
            struct Perfs: Decodable {
                let rapid: Perf?
                let blitz: Perf?
                let bullet: Perf?
                struct Perf: Decodable { let rating: Int? }
            }
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let user = try JSONDecoder().decode(LichessUser.self, from: data)
        let rating = user.perfs?.rapid?.rating ?? user.perfs?.blitz?.rating ?? user.perfs?.bullet?.rating
        return QuickProfile(username: username, displayName: user.username, rating: rating)
    }

    // MARK: - Convenience
    /// Fetches every game played on `platform` in the last `days` days --
    /// used by the "Sync Last 30 Days" puzzle-import flow.
    func fetchRecentGames(platform: ExternalGame.Platform, username: String, days: Int) async throws -> [ExternalGame] {
        switch platform {
        case .chesscom:
            return try await fetchChesscomGames(username: username, sinceDaysAgo: days)
        case .lichess:
            // Lichess has no hard result cap tied to the date window, but we
            // still bound it generously so a very active player's sync stays fast.
            return try await fetchLichessGames(username: username, maxGames: 200, sinceDaysAgo: days)
        }
    }

    func fetchGames(platform: ExternalGame.Platform, username: String, maxGames: Int = 20) async {
        await MainActor.run { isFetching = true; lastError = nil }
        do {
            let games: [ExternalGame]
            switch platform {
            case .chesscom: games = try await fetchChesscomGames(username: username, maxGames: maxGames)
            case .lichess:  games = try await fetchLichessGames(username: username, maxGames: maxGames)
            }
            await MainActor.run {
                recentGames = games
                isFetching = false
            }
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
                isFetching = false
            }
        }
    }
}

// MARK: - PGN → ChessGame Converter
/// Minimal PGN parser that converts a single-game PGN string to a `ChessGame`.
/// Handles standard moves, captures, castling, and promotion notation.
struct PGNImporter {

    static func importGame(_ pgn: String) -> ChessGame? {
        let lines = pgn.components(separatedBy: "\n")
        var whitePlayer = "White"
        var blackPlayer = "Black"

        // Parse headers
        for line in lines where line.hasPrefix("[") {
            if line.hasPrefix("[White ") {
                whitePlayer = extractHeaderValue(line)
            } else if line.hasPrefix("[Black ") {
                blackPlayer = extractHeaderValue(line)
            }
        }

        // Extract move text: everything after the last header line
        let moveText = lines
            .filter { !$0.hasPrefix("[") && !$0.isEmpty }
            .joined(separator: " ")

        let game = ChessGame(whitePlayer: whitePlayer, blackPlayer: blackPlayer)
        let engine = ChessEngineService.shared
        var board = game.board

        // Tokenize: remove move numbers and result tokens, keep SAN moves
        let tokens = moveText
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .filter { !$0.contains(".") || $0.filter({ $0 == "." }).count == $0.count }
            .filter { !["1-0","0-1","1/2-1/2","*"].contains($0) }
            // Filter out purely numeric tokens (move numbers like "1", "2" …)
            .filter { token -> Bool in
                let stripped = token.trimmingCharacters(in: CharacterSet(charactersIn: "."))
                return Int(stripped) == nil
            }

        for token in tokens {
            // Skip annotation tokens (?, !, +, #)
            let cleanToken = token
                .replacingOccurrences(of: "+", with: "")
                .replacingOccurrences(of: "#", with: "")
                .replacingOccurrences(of: "!", with: "")
                .replacingOccurrences(of: "?", with: "")

            if let move = findMove(for: cleanToken, on: board, engine: engine) {
                game.makeMove(move)
                board = game.board
            }
        }

        return game.moves.isEmpty ? nil : game
    }

    private static func extractHeaderValue(_ line: String) -> String {
        guard let start = line.firstIndex(of: "\""),
              let end = line.lastIndex(of: "\""),
              start != end else { return "" }
        return String(line[line.index(after: start)..<end])
    }

    // MARK: SAN → ChessMove resolver
    private static func findMove(for san: String, on board: ChessBoard, engine: ChessEngineService) -> ChessMove? {
        let color = board.activeColor
        let allMoves = engine.legalMoves(for: color, on: board)

        // Castling
        if san == "O-O"   { return allMoves.first(where: { $0.isCastling && $0.to.file == 6 }) }
        if san == "O-O-O" { return allMoves.first(where: { $0.isCastling && $0.to.file == 2 }) }

        var s = san

        // Promotion piece
        var promoType: PieceType? = nil
        if s.contains("=") {
            let parts = s.components(separatedBy: "=")
            s = parts[0]
            promoType = pieceType(from: parts.last ?? "")
        }

        // Determine destination square (last two chars before possible promo)
        guard s.count >= 2 else { return nil }
        let destStr = String(s.suffix(2))
        guard let dest = Square(algebraic: destStr) else { return nil }

        // Piece type
        let firstChar = s.first!
        let movingPieceType: PieceType
        if firstChar.isUppercase && firstChar != "O" {
            movingPieceType = pieceType(from: String(firstChar)) ?? .pawn
            s = String(s.dropFirst())
        } else {
            movingPieceType = .pawn
        }

        // Disambiguation (file or rank character)
        let disambig = s.dropLast(2).replacingOccurrences(of: "x", with: "")

        let candidates = allMoves.filter { move in
            guard move.piece.type == movingPieceType,
                  move.to == dest,
                  move.promotionPiece == promoType else { return false }
            if disambig.isEmpty { return true }
            if let file = "abcdefgh".firstIndex(of: Character(disambig)) {
                let fileIdx = "abcdefgh".distance(from: "abcdefgh".startIndex, to: file)
                if move.from.file == fileIdx { return true }
            }
            if let rank = Int(disambig) {
                if move.from.rank == rank - 1 { return true }
            }
            return false
        }
        return candidates.first
    }

    private static func pieceType(from char: String) -> PieceType? {
        switch char.uppercased() {
        case "K": return .king
        case "Q": return .queen
        case "R": return .rook
        case "B": return .bishop
        case "N": return .knight
        case "P": return .pawn
        default:  return nil
        }
    }
}
