import SwiftUI

struct DayRowView: View {
    let day: DayBucket
    let layout: AxisLayout
    var isFocused: Bool = false

    @State private var selectedEvent: DayEvent?
    @State private var showingAllDayList = false
    @State private var showingSummary = false

    private var rowHeight: CGFloat {
        isFocused ? DR.dayRowHeight * 3 : DR.dayRowHeight
    }

    private static let weekdayFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f
    }()
    private static let dayNumFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d"; return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                dayLabel
                    .frame(width: DR.dayLabelWidth, height: rowHeight, alignment: .topLeading)
                Group {
                    if isFocused {
                        focusedTrack.transition(.opacity)
                    } else {
                        track.transition(.opacity)
                    }
                }
                .frame(width: layout.width, height: rowHeight, alignment: .topLeading)
            }
            .padding(.horizontal, DR.horizontalPadding)
            if isFocused {
                // The hour-axis labels belong to the timeline rows below the focused
                // day, not the focused day's card list — so they live at the bottom
                // of the focused row and travel with it as the user scrolls.
                hoursBar.transition(.opacity)
            }
            // Row separator lives inside the row so each DayRowView is exactly one
            // scroll-snap target; scroll alignment matches the row's visible top edge.
            Rectangle()
                .fill(DR.rule)
                .frame(height: DR.hairline)
        }
        // Focused rows draw their own opaque surface so the global timeline grid
        // (drawn behind the LazyVStack) doesn't bleed through the cards or the hour bar.
        .background(isFocused ? DR.surface : Color.clear)
        .animation(.snappy(duration: 0.25), value: isFocused)
        .sheet(isPresented: $showingSummary) {
            DaySummarySheet(day: day)
        }
    }

    private var hoursBar: some View {
        HStack(alignment: .top, spacing: 8) {
            Spacer().frame(width: DR.dayLabelWidth)
            TimeAxisHeader(layout: layout)
                .frame(height: DR.timeHeaderHeight)
        }
        .padding(.horizontal, DR.horizontalPadding)
        .padding(.top, 4)
        .padding(.bottom, 2)
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
                    Button {
                        showingSummary = true
                    } label: {
                        Text(Self.dayNumFmt.string(from: day.date))
                            .font(day.isToday ? DR.TypeStyle.dayNumberToday : DR.TypeStyle.dayNumber)
                            .foregroundStyle(day.isToday ? DR.accent : DR.ink)
                            .frame(width: 30, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
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

    // MARK: - Focused track (the expanded top row)

    @ViewBuilder
    private var focusedTrack: some View {
        let sorted = day.timedEvents.sorted { $0.startMinute < $1.startMinute }
        let morning = sorted.filter { $0.startMinute < 12 * 60 }
        let afternoon = sorted.filter { $0.startMinute >= 12 * 60 }
        let nothing = day.allDayEvents.isEmpty && sorted.isEmpty

        VStack(alignment: .leading, spacing: 8) {
            if !day.allDayEvents.isEmpty {
                allDayInlineRow
            }
            if !sorted.isEmpty {
                HStack(alignment: .top, spacing: 0) {
                    timeOfDayColumn(title: "Morning", events: morning)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    Rectangle()
                        .fill(DR.rule)
                        .frame(width: DR.hairline)
                        .padding(.horizontal, 6)
                    timeOfDayColumn(title: "Afternoon", events: afternoon)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            if nothing {
                Text("No events")
                    .font(.system(size: 13))
                    .foregroundStyle(DR.inkSecondary)
                    .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    private var allDayInlineRow: some View {
        HStack(spacing: 10) {
            ForEach(day.allDayEvents) { ev in
                allDayChip(ev)
            }
            Spacer(minLength: 0)
        }
    }

    private func allDayChip(_ ev: DayEvent) -> some View {
        HStack(spacing: 4) {
            Circle().fill(ev.color).frame(width: 5, height: 5)
            Text(ev.title)
                .font(.system(size: 11))
                .foregroundStyle(DR.ink)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        .onTapGesture { selectedEvent = ev }
        .popover(
            isPresented: Binding(
                get: { selectedEvent?.id == ev.id },
                set: { presenting in if !presenting { selectedEvent = nil } }
            )
        ) {
            eventPopoverContent(ev)
        }
    }

    private func timeOfDayColumn(title: String, events: [DayEvent]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(DR.inkSecondary)
                .tracking(0.6)
            if events.isEmpty {
                Text("—")
                    .font(.system(size: 11))
                    .foregroundStyle(DR.inkTertiary)
            } else {
                let shown = Array(events.prefix(4))
                let overflow = events.count - shown.count
                ForEach(shown) { ev in
                    focusedHorizontalCard(ev)
                }
                if overflow > 0 {
                    Text("+\(overflow)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DR.inkSecondary)
                        .padding(.leading, 6)
                }
            }
        }
    }

    private func focusedHorizontalCard(_ ev: DayEvent) -> some View {
        HStack(spacing: 6) {
            Rectangle().fill(ev.color).frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(ev.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DR.ink)
                    .lineLimit(1)
                Text(TimeAxis.hourLabel(ev.startMinute))
                    .font(.system(size: 10))
                    .foregroundStyle(DR.inkSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ev.color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .contentShape(Rectangle())
        .onTapGesture { selectedEvent = ev }
        .popover(
            isPresented: Binding(
                get: { selectedEvent?.id == ev.id },
                set: { presenting in if !presenting { selectedEvent = nil } }
            )
        ) {
            eventPopoverContent(ev)
        }
    }

    // MARK: - Track

    private var track: some View {
        let items = LanePacker.pack(day.timedEvents)
        let placements = computePlacements(for: items)
        return ZStack(alignment: .topLeading) {
            // Events. The empty-hour shading and the hour gridlines are drawn
            // globally on the LazyVStack (see CalendarTimelineView) so they stay
            // continuous from top to bottom across every day row.
            ForEach(items, id: \.event.id) { item in
                eventView(for: item, placement: placements[item.event.id] ?? .none)
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
    private func eventView(for item: LanePacker.Item, placement: LabelPlacement) -> some View {
        let startX = layout.x(forMinute: item.event.startMinute)
        let endX = layout.x(forMinute: item.event.endMinute)
        let blockWidth = max(3, endX - startX)
        let usableHeight = DR.dayRowHeight - 16
        let laneHeight = usableHeight / CGFloat(max(1, item.totalLanes))
        let topY = 8 + CGFloat(item.lane) * laneHeight
        let blockHeight = laneHeight - 2

        let leftLabelWidth: CGFloat = {
            if case .left(let w) = placement { return w }
            return 0
        }()
        let hStackOffsetX = startX - (leftLabelWidth > 0 ? leftLabelWidth + 4 : 0)

        HStack(spacing: 4) {
            if case .left(let w) = placement {
                Text(item.event.title)
                    .font(DR.TypeStyle.eventTitle)
                    .foregroundStyle(DR.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: w, height: blockHeight, alignment: .trailing)
            }
            EventBlock(event: item.event, showLabel: placement == .inside)
                .frame(width: blockWidth, height: blockHeight)
            if case .right(let w) = placement {
                Text(item.event.title)
                    .font(DR.TypeStyle.eventTitle)
                    .foregroundStyle(DR.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: w, height: blockHeight, alignment: .leading)
            }
        }
        .contentShape(Rectangle())
        .offset(x: hStackOffsetX, y: topY)
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

    // MARK: - Label placement

    private enum LabelPlacement: Equatable {
        case inside
        case right(width: CGFloat)
        case left(width: CGFloat)
        case none
    }

    /// Decide where each event's title sits. Priority inside → right → left; an event
    /// only uses the gap to its left if the previous event on the lane didn't already
    /// claim that gap with a right label.
    private func computePlacements(for items: [LanePacker.Item]) -> [String: LabelPlacement] {
        let insideMin: CGFloat = 32
        let externalMin: CGFloat = 32

        var result: [String: LabelPlacement] = [:]
        let groups = Dictionary(grouping: items, by: \.lane)
        for (_, group) in groups {
            let sorted = group.sorted { $0.event.startMinute < $1.event.startMinute }
            var prev: LabelPlacement = .none
            for (i, cur) in sorted.enumerated() {
                let startX = layout.x(forMinute: cur.event.startMinute)
                let endX = layout.x(forMinute: cur.event.endMinute)
                let blockWidth = max(3, endX - startX)

                let prevEnd = i > 0 ? sorted[i - 1].event.endMinute : 0
                let nextStart = i + 1 < sorted.count ? sorted[i + 1].event.startMinute : 1440
                let leftGap = max(0, startX - layout.x(forMinute: prevEnd))
                let rightGap = max(0, layout.x(forMinute: nextStart) - endX)

                let placement: LabelPlacement
                if blockWidth >= insideMin {
                    placement = .inside
                } else if rightGap >= externalMin {
                    placement = .right(width: rightGap - 4)
                } else if leftGap >= externalMin, !Self.isRight(prev) {
                    placement = .left(width: leftGap - 4)
                } else {
                    placement = .none
                }
                result[cur.event.id] = placement
                prev = placement
            }
        }
        return result
    }

    private static func isRight(_ p: LabelPlacement) -> Bool {
        if case .right = p { return true } else { return false }
    }

    private func currentMinuteOfDay() -> Int {
        let cal = Calendar.current
        let now = Date()
        return cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
    }
}
