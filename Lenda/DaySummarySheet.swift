import SwiftUI

/// A sheet showing the day's events and an on-demand AI-generated summary.
struct DaySummarySheet: View {
    let day: DayBucket

    @State private var summary: String?
    @State private var loading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private static let titleFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summarySection
                    eventsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(Self.titleFmt.string(from: day.date))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Summary

    @ViewBuilder
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundStyle(DR.accent)
                Text("AI summary")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DR.inkSecondary)
                    .textCase(.uppercase)
            }

            if let summary {
                Text(summary)
                    .font(.system(size: 15))
                    .foregroundStyle(DR.ink)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            } else if loading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Generating…")
                        .font(.system(size: 13))
                        .foregroundStyle(DR.inkSecondary)
                }
            } else {
                Button {
                    Task { await generate() }
                } label: {
                    Text("Generate summary")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(DR.accent))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Events

    @ViewBuilder
    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Events")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DR.inkSecondary)
                .textCase(.uppercase)

            if day.allDayEvents.isEmpty, day.timedEvents.isEmpty {
                Text("No events scheduled.")
                    .font(.system(size: 14))
                    .foregroundStyle(DR.inkSecondary)
            }
            ForEach(day.allDayEvents) { ev in
                eventRow(ev, subtitle: "All-day")
            }
            ForEach(day.timedEvents.sorted { $0.startMinute < $1.startMinute }) { ev in
                eventRow(
                    ev,
                    subtitle: "\(TimeAxis.hourLabel(ev.startMinute))–\(TimeAxis.hourLabel(ev.endMinute))"
                        + (ev.location.flatMap { $0.isEmpty ? nil : " · \($0)" } ?? "")
                )
            }
        }
    }

    private func eventRow(_ ev: DayEvent, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Rectangle().fill(ev.color).frame(width: 3, height: 28)
            VStack(alignment: .leading, spacing: 0) {
                Text(ev.title).font(.system(size: 14)).foregroundStyle(DR.ink)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(DR.inkSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Generation

    private func generate() async {
        loading = true
        errorMessage = nil
        defer { loading = false }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            do {
                let service = AppleFoundationSummaryService()
                summary = try await service.summarize(day: day)
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            errorMessage = "Day summaries require iOS 26 or later."
        }
        #else
        errorMessage = "Day summaries require Xcode 26 with the FoundationModels SDK."
        #endif
    }
}
