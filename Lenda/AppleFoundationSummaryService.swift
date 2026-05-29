import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// Day summarizer backed by Apple Intelligence's on-device foundation model.
/// Free, private, and offline — but only on iOS 26+ on an Apple-Intelligence-
/// capable device with the model finished downloading.
@available(iOS 26.0, *)
struct AppleFoundationSummaryService: SummaryService {

    static let instructions = """
    You write short, friendly summaries of a single day on someone's calendar. \
    Given a list of events with times and titles, produce 2–3 natural sentences \
    that read like a knowledgeable assistant briefing a friend. Mention the \
    events by name. Don't list them mechanically. If the day is empty, say so \
    in one sentence.
    """

    func summarize(day: DayBucket) async throws -> String {
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            throw SummaryError.unavailable(reason: Self.unavailableMessage(for: model))
        }
        let session = LanguageModelSession(instructions: Self.instructions)
        let response = try await session.respond(to: Self.buildPrompt(for: day))
        return response.content
    }

    static func unavailableMessage(for model: SystemLanguageModel) -> String {
        switch model.availability {
        case .available:
            return ""
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Turn on Apple Intelligence in Settings to generate day summaries."
        case .unavailable(.modelNotReady):
            return "Apple Intelligence is still downloading. Try again in a few minutes."
        case .unavailable(.deviceNotEligible):
            return "This device doesn't support Apple Intelligence, so on-device summaries aren't available."
        case .unavailable:
            return "Apple Intelligence isn't available on this device right now."
        }
    }

    static func buildPrompt(for day: DayBucket) -> String {
        let dayFmt = DateFormatter()
        dayFmt.dateStyle = .full
        var lines = ["Date: \(dayFmt.string(from: day.date))"]
        if day.allDayEvents.isEmpty, day.timedEvents.isEmpty {
            lines.append("No events scheduled.")
            return lines.joined(separator: "\n")
        }
        if !day.allDayEvents.isEmpty {
            lines.append("All-day:")
            for ev in day.allDayEvents {
                lines.append("- \(ev.title)")
            }
        }
        if !day.timedEvents.isEmpty {
            lines.append("Timed events:")
            let sorted = day.timedEvents.sorted { $0.startMinute < $1.startMinute }
            for ev in sorted {
                let start = TimeAxis.hourLabel(ev.startMinute)
                let end = TimeAxis.hourLabel(ev.endMinute)
                var line = "- \(ev.title) (\(start)–\(end))"
                if let loc = ev.location, !loc.isEmpty {
                    line += " at \(loc)"
                }
                lines.append(line)
            }
        }
        return lines.joined(separator: "\n")
    }
}
#endif
