import SwiftUI

struct DayRowView: View {
    let day: DayBucket
    let layout: AxisLayout

    private static let weekdayFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()
    private static let dayNumFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            dayLabel
                .frame(width: DR.dayLabelWidth, height: DR.dayRowHeight, alignment: .topLeading)
            track
                .frame(width: layout.width, height: DR.dayRowHeight)
        }
        .padding(.horizontal, DR.horizontalPadding)
        .background(DR.surface)
    }

    // MARK: - Day label

    private var dayLabel: some View {
        HStack(alignment: .top, spacing: 6) {
            if day.isToday {
                Rectangle()
                    .fill(DR.accent)
                    .frame(width: 2)
                    .padding(.vertical, 4)
            } else {
                Color.clear.frame(width: 2)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(Self.weekdayFmt.string(from: day.date).uppercased())
                    .font(DR.TypeStyle.weekday)
                    .foregroundStyle(day.isToday ? DR.accent : DR.inkSecondary)
                Text(Self.dayNumFmt.string(from: day.date))
                    .font(day.isToday ? DR.TypeStyle.dayNumberToday : DR.TypeStyle.dayNumber)
                    .foregroundStyle(day.isToday ? DR.accent : DR.ink)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Track

    private var bannerSectionHeight: CGFloat {
        day.allDayEvents.isEmpty ? 0 : 18
    }

    private var track: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !day.allDayEvents.isEmpty {
                allDayBanners
                    .frame(height: bannerSectionHeight, alignment: .topLeading)
            }
            timedTrack
        }
    }

    private var allDayBanners: some View {
        HStack(spacing: 4) {
            ForEach(day.allDayEvents.prefix(3), id: \.id) { event in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(event.color)
                        .frame(width: 2)
                    Text(event.title)
                        .font(DR.TypeStyle.eventTitle)
                        .foregroundStyle(DR.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, 4)
                        .background(event.color.opacity(0.18))
                }
                .frame(height: 14)
            }
            if day.allDayEvents.count > 3 {
                Text("+\(day.allDayEvents.count - 3)")
                    .font(DR.TypeStyle.allDayHint)
                    .foregroundStyle(DR.inkTertiary)
            }
            Spacer(minLength: 0)
        }
    }

    private var timedTrack: some View {
        ZStack(alignment: .topLeading) {
            // Compressed regions: a slightly darker tint, no hatching, no icon — silence.
            ForEach(layout.compressedRanges) { range in
                Rectangle()
                    .fill(DR.surfaceCompressed)
                    .frame(width: max(0, range.endX - range.startX))
                    .offset(x: range.startX)
            }

            // Hour gridlines: hairline only, slightly stronger at compressed boundaries.
            ForEach(layout.hourTicks) { tick in
                Rectangle()
                    .fill(tick.isCompressedBoundary ? DR.ruleStrong.opacity(0.5) : DR.rule)
                    .frame(width: DR.hairline)
                    .offset(x: tick.x)
                    .allowsHitTesting(false)
            }

            // Events, lane-packed
            ForEach(LanePacker.pack(day.timedEvents), id: \.event.id) { item in
                let startX = layout.x(forMinute: item.event.startMinute)
                let endX = layout.x(forMinute: item.event.endMinute)
                let usableHeight = DR.dayRowHeight - bannerSectionHeight - 16
                let laneHeight = usableHeight / CGFloat(max(1, item.totalLanes))
                EventBlock(event: item.event)
                    .frame(width: max(3, endX - startX), height: laneHeight - 2)
                    .offset(x: startX, y: 8 + CGFloat(item.lane) * laneHeight)
            }

            // Now indicator on today only.
            if day.isToday {
                let nowX = layout.x(forMinute: currentMinuteOfDay())
                Rectangle()
                    .fill(DR.accent)
                    .frame(width: 1)
                    .offset(x: nowX)
                    .allowsHitTesting(false)
                Circle()
                    .fill(DR.accent)
                    .frame(width: 5, height: 5)
                    .offset(x: nowX - 2, y: -2)
            }
        }
    }

    private func currentMinuteOfDay() -> Int {
        let cal = Calendar.current
        let now = Date()
        return cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
    }
}
