import Foundation

/// Generates a short, friendly summary of one day's calendar events.
protocol SummaryService {
    func summarize(day: DayBucket) async throws -> String
}

enum SummaryError: LocalizedError {
    case unavailable(reason: String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let reason): return reason
        }
    }
}
