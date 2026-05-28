import SwiftUI

struct DayRowView: View {
    let day: DayBucket
    let layout: AxisLayout

    @State private var selectedEvent: DayEvent?
    @State private var showingAllDayList = false

    private static let weekdayFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f
    }()
    private static let dayNumFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d"; return f
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
                Rectangle().fill(DR.accent).frame(width: 2).padding(.vertical, 4)
            } else {
                Color.clear.frame(width: 2)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(Self.weekdayFmt.string(from: day.date).uppercased())
                    .font(DR.TypeStyle.weekday)
                    .foregroundStyle(day.isToday ? DR.accent : DR.inkSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Self.dayNumFmt.string(from: day.date))
                        .font(day.isToday ? DR.TypeStyle.dayNumberToday : DR.TypeStyle.dayNumber)
                        .foregroundStyle(day.isToday ? DR.accent : DR.ink)
                    if !day.allDayEvents.isEmpty { allDayBadge }
                }
            }
        }
        .padding(.top, 8)
    }

    private var allDayBadge: some View {
        Button {
            showingAllDayList = true
        } label: {
            Text("\(day.allDayEvents.count)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    Capsule().fill(day.allDayEvents.first?.color ?? DR.accent)
                )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingAllDayList) {
            VStack(alignment: .leading, spacing: 6) {
                Text("All-day")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DR.inkSecondary)
                ForEach(day.allDayEvents) { ev in
                    HStack(spacing: 6) {
                        Circle().fill(ev.color).frame(width: 6, height: 6)
                        Text(ev.title)
                            .font(.system(size: 13))
                            .foregroundStyle(DR.ink)
                    }
                }
            }
            .padding(12)
            .presentationCompactAdaptation(.popover)
        }
    }

    // MARK: - Track

    private var track: some View {
        let items = LanePacker.pack(day.timedEvents)
        let nextOnLane = computeNextOnLane(items)
        return ZStack(alignment: .topLeading) {
            // Shade hours with no activity so dead time is visible.
            ForEach(layout.hourTicks.filter { $0.isEmpty && $0.width > 0 }) { tick in
                Rectangle()
                    .fill(DR.surfaceCompressed)
                    .frame(width: tick.width)
                    .offset(x: tick.x)
            }

            // Hour gridlines
            ForEach(layout.hourTicks) { tick in
                Rectangle()
                    .fill(DR.rule)
                    .frame(width: DR.hairline)
                    .offset(x: tick.x)
                    .allowsHitTesting(false)
            }

            // Events
            ForEach(items, id: \.event.id) { item in
                eventView(for: item, nextStartMinute: nextOnLane[item.event.id] ?? 1440)
            }

            // Now indicator on today only
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

    @ViewBuilder
    private func eventView(for item: LanePacker.Item, nextStartMinute: Int) -> some View {
        let startX = layout.x(forMinute: item.event.startMinute)
        let endX = layout.x(forMinute: item.event.endMinute)
        let blockWidth = max(3, endX - startX)
        let usableHeight = DR.dayRowHeight - 16
        let laneHeight = usableHeight / CGFloat(max(1, item.totalLanes))
        let topY = 8 + CGFloat(item.lane) * laneHeight
        let blockHeight = laneHeight - 2

        let nextStartX = layout.x(forMinute: nextStartMinute)
        let gapWidth = max(0, nextStartX - endX)

        let insideMin: CGFloat = 50
        let externalMin: CGFloat = 44
        let externalLabelWidth: CGFloat = {
            if blockWidth >= insideMin { return 0 }
            if gapWidth >= externalMin { return gapWidth - 4 }
            return 0
        }()
        let showInsideLabel = blockWidth >= insideMin

        HStack(spacing: 4) {
            EventBlock(event: item.event, showLabel: showInsideLabel)
                .frame(width: blockWidth, height: blockHeight)
            if externalLabelWidth > 0 {
                Text(item.event.title)
                    .font(DR.TypeStyle.eventTitle)
                    .foregroundStyle(DR.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: externalLabelWidth, height: blockHeight, alignment: .leading)
            }
        }
        .contentShape(Rectangle())
        .offset(x: startX, y: topY)
        .onTapGesture { selectedEvent = item.event }
        .popover(
            isPresented: Binding(
                get: { selectedEvent?.id == item.event.id },
                set: { presenting in if !presenting { selectedEvent = nil } }
            )
        ) {
            eventPopoverContent(item.event)
        }
    }

    private func eventPopoverContent(_ event: DayEvent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(event.color).frame(width: 8, height: 8)
                Text(event.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DR.ink)
            }
            Text("\(TimeAxis.hourLabel(event.startMinute)) – \(TimeAxis.hourLabel(event.endMinute))")
                .font(.system(size: 12))
                .foregroundStyle(DR.inkSecondary)
            if let loc = event.location, !loc.isEmpty {
                Text(loc)
                    .font(.system(size: 12))
                    .foregroundStyle(DR.inkTertiary)
            }
        }
        .padding(12)
        .presentationCompactAdaptation(.popover)
    }

    private func computeNextOnLane(_ items: [LanePacker.Item]) -> [String: Int] {
        var result: [String: Int] = [:]
        let groups = Dictionary(grouping: items, by: \.lane)
        for (_, group) in groups {
            let sorted = group.sorted { $0.event.startMinute < $1.event.startMinute }
            for (i, item) in sorted.enumerated() {
                result[item.event.id] = i + 1 < sorted.count
                    ? sorted[i + 1].event.startMinute
                    : 1440
            }
        }
        return result
    }

    private func currentMinuteOfDay() -> Int {
        let cal = Calendar.current
        let now = Date()
        return cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
    }
}
