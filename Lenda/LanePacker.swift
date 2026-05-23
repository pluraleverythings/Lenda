import Foundation

/// Greedy lane packer: lays out time-overlapping events across as few horizontal lanes
/// (rows-within-a-row) as possible. Stable: items are returned in start-time order, and
/// each item gets the lowest-indexed free lane.
enum LanePacker {
    struct Item: Equatable {
        let event: DayEvent
        let lane: Int
        let totalLanes: Int
    }

    static func pack(_ events: [DayEvent]) -> [Item] {
        let sorted = events.sorted {
            $0.startMinute != $1.startMinute
                ? $0.startMinute < $1.startMinute
                : $0.endMinute < $1.endMinute
        }
        var laneEnd: [Int] = []
        var assignedLane: [String: Int] = [:]
        for ev in sorted {
            var placed = false
            for i in laneEnd.indices where laneEnd[i] <= ev.startMinute {
                assignedLane[ev.id] = i
                laneEnd[i] = ev.endMinute
                placed = true
                break
            }
            if !placed {
                assignedLane[ev.id] = laneEnd.count
                laneEnd.append(ev.endMinute)
            }
        }
        let total = max(1, laneEnd.count)
        return sorted.map { Item(event: $0, lane: assignedLane[$0.id] ?? 0, totalLanes: total) }
    }
}
