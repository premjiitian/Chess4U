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
        let archivesURL = URL(string: "https://api.chess.com/pub/player/\(username.lowercased())/games/archives")!
        let (archivesData, _) = try await URLSession.shared.data(from: archivesURL)

        struct Archives: Decodable { let archives: [String] }
        let archives = try JSONDecoder().decode(Archives.self, from: archivesData)
        guard let latestArchiveURLStr = archives.archives.last,
              let latestURL = URL(string: latestArchiveURLStr) else {
            return []
        }

        let (gamesData, _) = try await URLSession.shared.data(from: latestURL)

        struct ChesscomGame: Decodable {
            let pgn: String?
            let white: Player
            let black: Player
            let end_time: Int
            let time_control: String
            struct Player: Decodable { let username: String; let result: String }
        }
        struct ChesscomResponse: Decodable { let games: [ChesscomGame] }

        let response = try JSONDecoder().decode(ChesscomResponse.self, from: gamesData)
        let games = response.games.suffix(maxGames).compactMap { g -> ExternalGame? in
            guard let pgn = g.pgn, !pgn.isEmpty else { return nil }
            return ExternalGame(
                id: "\(g.end_time)-\(g.white.username)-\(g.black.username)",
                pgn: pgn,
                platform: .chesscom,
                whitePlayer: g.white.username,
                blackPlayer: g.black.username,
                result: g.white.result == "win" ? "1-0" : g.black.result == "win" ? "0-1" : "1/2-1/2",
                timeControl: g.time_control,
                endTime: Date(timeIntervalSince1970: TimeInterval(g.end_time))
            )
        }
        return games.reversed()
    }

    // MARK: - Lichess API
    /// Fetches the most recent `maxGames` games for a Lichess user (exported as PGN).
    func fetchLichessGames(username: String, maxGames: Int = 20) async throws -> [ExternalGame] {
        var components = URLComponents(string: "https://lichess.org/api/games/user/\(username.lowercased())")!
        components.queryItems = [
            URLQueryItem(name: "max", value: "\(maxGames)"),
            URLQueryItem(name: "pgnInJson", value: "true"),
            URLQueryItem(name: "clocks", value: "false"),
            URLQueryItem(name: "evals", value: "false")
        ]
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
                endTime: Date()
            ))
        }
        return games
    }

    // MARK: - Convenience
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
