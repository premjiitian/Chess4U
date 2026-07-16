import Foundation

/// A single Stockfish evaluation of one position, as returned by the cloud API.
struct StockfishAnalysis {
    /// Evaluation in pawns, from White's perspective. Nil when `mateIn` is set.
    let evaluation: Double?
    /// Moves to forced mate (positive = White mates, negative = Black mates,
    /// 0 = already checkmate). Nil when there is no forced mate.
    let mateIn: Int?
    /// The engine's recommended move, in UCI long-algebraic form ("e2e4", "e7e8q").
    let bestMoveUCI: String?
    let ponderUCI: String?
    let continuationUCI: [String]

    /// A single pawn-scale number suitable for an evaluation bar/graph,
    /// collapsing forced-mate scores into a large but finite value so callers
    /// don't need to special-case `mate` separately from `evaluation`.
    var evaluationPawns: Double {
        if let mate = mateIn {
            if mate == 0 { return -9.0 } // side to move is already checkmated
            return mate > 0 ? 9.0 : -9.0
        }
        return evaluation ?? 0
    }
}

enum StockfishCloudError: Error {
    case network
    case rateLimited
    case badResponse
    case apiError(String)
}

/// Thin client for the free stockfish.online REST API -- runs real, current
/// Stockfish server-side so the app doesn't need to compile the engine (and
/// its GPL-3.0 license) into the binary. Every call has a short timeout and
/// callers are expected to fall back to `ChessEngineService`'s local
/// evaluator when this throws (no network, rate-limited, service down).
final class StockfishCloudService: @unchecked Sendable {
    static let shared = StockfishCloudService()

    private let endpoint = "https://stockfish.online/api/s/v2.php"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 8
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)
    }

    /// Analyzes a position given its FEN. `depth` is clamped to the API's
    /// supported range (1...15) -- higher depth is stronger but slower.
    func analyze(fen: String, depth: Int) async throws -> StockfishAnalysis {
        var components = URLComponents(string: endpoint)
        components?.queryItems = [
            URLQueryItem(name: "fen", value: fen),
            URLQueryItem(name: "depth", value: String(min(max(depth, 1), 15)))
        ]
        guard let url = components?.url else { throw StockfishCloudError.badResponse }

        // The API 403s clients without an identifying User-Agent (verified
        // against this exact endpoint) -- always send one.
        var request = URLRequest(url: url)
        request.setValue("Chess4U-iOS (https://github.com/premjiitian/Chess4U)", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw StockfishCloudError.network
        }

        guard let http = response as? HTTPURLResponse else { throw StockfishCloudError.network }
        if http.statusCode == 429 { throw StockfishCloudError.rateLimited }
        guard (200...299).contains(http.statusCode) else { throw StockfishCloudError.badResponse }

        let decoded: RawResponse
        do {
            decoded = try JSONDecoder().decode(RawResponse.self, from: data)
        } catch {
            throw StockfishCloudError.badResponse
        }

        guard decoded.success else {
            throw StockfishCloudError.apiError(decoded.data ?? "unknown error")
        }

        // bestmove field looks like "bestmove e7e5 ponder g1f3"
        let tokens = (decoded.bestmove ?? "").split(separator: " ").map(String.init)
        var bestMove: String? = nil
        var ponder: String? = nil
        if tokens.count >= 2, tokens[0] == "bestmove" { bestMove = tokens[1] }
        if tokens.count >= 4, tokens[2] == "ponder" { ponder = tokens[3] }

        let continuation = (decoded.continuation ?? "").split(separator: " ").map(String.init)

        return StockfishAnalysis(
            evaluation: decoded.evaluation,
            mateIn: decoded.mate,
            bestMoveUCI: bestMove,
            ponderUCI: ponder,
            continuationUCI: continuation
        )
    }

    private struct RawResponse: Decodable {
        let success: Bool
        let evaluation: Double?
        let mate: Int?
        let bestmove: String?
        let continuation: String?
        /// Present with an error message when `success` is false.
        let data: String?
    }
}
