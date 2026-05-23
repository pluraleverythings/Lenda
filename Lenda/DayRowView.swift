import SwiftUI

struct DayRowView: View {
    let day: DayBucket
    let axis: TimeAxis
    let dayLabelWidth: CGFloat

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

    private static let rowHeight: CGFloat = 72

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            dayLabel
                .frame(width: dayLabelWidth, alignment: .leading)
            track
        }
        .padding(.horizontal, 8)
    }

    private var dayLabel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Self.weekdayFmt.string(from: day.date).uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(day.isToday ? Color.accentColor : .secondary)
            Text(Self.dayNumFmt.string(from: day.date))
                .font(.title2.weight(day.isToday ? .bold : .regular))
                .foregroundStyle(day.isToday ? Color.accentColor : .primary)
            if !day.allDayEvents.isEmpty {
                Text("\(day.allDayEvents.count) all-day")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(height: Self.rowHeight, alignment: .top)
        .padding(.top, 2)
    }

    private var track: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.secondarySystemBackground))

                // Compressed zones
                ForEach(axis.compressedRanges(totalWidth: w)) { range in
                    CompressedZone(range: range)
                }

                // Hour gridlines
                ForEach(axis.hourTicks(totalWidth: w)) { tick in
                    Rectangle()
                        .fill(Color(.separator).opacity(tick.isCompressedBoundary ? 0.55 : 0.25))
                        .frame(width: tick.isCompressedBoundary ? 1 : 1)
                        .offset(x: tick.x)
                        .allowsHitTesting(false)
                }

                // Timed events with lane assignment for overlaps
                let lanes = assignLanes(day.timedEvents)
                ForEach(lanes, id: \.event.id) { item in
                    let startX = axis.x(forMinute: item.event.startMinutes, totalWidth: w)
                    let endX = axis.x(forMinute: item.event.endMinutes, totalWidth: w)
                    let laneCount = max(1, item.totalLanes)
                    let usableHeight = Self.rowHeight - 8
                    let laneHeight = usableHeight / CGFloat(laneCount)
                    EventBlock(event: item.event, compact: laneCount > 1)
                        .frame(width: max(3, endX - startX), height: laneHeight - 2)
                        .offset(x: startX,
                                y: 4 + CGFloat(item.lane) * laneHeight)
                }

                // "Now" indicator on today
                if day.isToday {
                    let nowMin = currentMinuteOfDay()
                    let nowX = axis.x(forMinute: nowMin, totalWidth: w)
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 2)
                        .offset(x: nowX - 1)
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                        .offset(x: nowX - 3, y: -3)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(day.isToday ? Color.accentColor.opacity(0.55) : Color.clear,
                            lineWidth: 1.5)
            )
        }
        .frame(height: Self.rowHeight)
    }

    private func currentMinuteOfDay() -> Int {
        let cal = Calendar.current
        let now = Date()
        return cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
    }

    // MARK: - Lane packing

    private struct LaneItem {
        let event: DayEvent
        let lane: Int
        let totalLanes: Int
    }

    private func assignLanes(_ events: [DayEvent]) -> [LaneItem] {
        let sorted = events.sorted { $0.startMinutes < $1.startMinutes }
        var laneEnd: [Int] = []
        var assignment: [String: Int] = [:]
        for ev in sorted {
            var placed = false
            for i in laneEnd.indices where laneEnd[i] <= ev.startMinutes {
                assignment[ev.id] = i
                laneEnd[i] = ev.endMinutes
                placed = true
                break
            }
            if !placed {
                assignment[ev.id] = laneEnd.count
                laneEnd.append(ev.endMinutes)
            }
        }
        let total = max(1, laneEnd.count)
        return sorted.map { LaneItem(event: $0, lane: assignment[$0.id] ?? 0, totalLanes: total) }
    }
}

private struct CompressedZone: View {
    let range: TimeAxis.CompressedRange

    var body: some View {
        ZStack {
            DiagonalHatch()
                .stroke(Color.secondary.opacity(0.35), lineWidth: 0.5)
                .background(Color(.tertiarySystemBackground))
                .clipped()
        }
        .frame(width: max(0, range.endX - range.startX))
        .offset(x: range.startX)
    }
}

private struct DiagonalHatch: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let spacing: CGFloat = 5
        var x: CGFloat = -rect.height
        while x < rect.width + rect.height {
            p.move(to: CGPoint(x: x, y: 0))
            p.addLine(to: CGPoint(x: x + rect.height, y: rect.height))
            x += spacing
        }
        return p
    }
}
