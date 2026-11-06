import CoreGraphics
import Foundation

/// A segment placed on the dial. Radii are fractions of the dial radius.
struct DialSlice: Identifiable, Hashable {
    let segment: EventSegment
    let innerRadius: CGFloat
    let outerRadius: CGFloat

    var id: String { segment.id }
    var startHour: Double { Double(segment.startMinute) / 60 }
    var endHour: Double { Double(segment.endMinute) / 60 }
    var midHour: Double { (startHour + endHour) / 2 }
    var spanHours: Double { endHour - startHour }
}

/// Lays out event segments as pie slices. Overlapping events split the radius into lanes,
/// so every event stays visible; events that overlap nothing keep the whole slice.
enum SliceLayout {
    static func slices(for segments: [EventSegment], innerRadius: CGFloat, outerRadius: CGFloat) -> [DialSlice] {
        let count = segments.count
        guard count > 0 else { return [] }

        // Group overlapping segments into clusters (union-find).
        var parent = Array(0..<count)
        func root(_ index: Int) -> Int {
            var current = index
            while parent[current] != current {
                current = parent[current]
            }
            return current
        }
        for first in 0..<count {
            for second in (first + 1)..<count where segments[first].overlaps(segments[second]) {
                let firstRoot = root(first)
                let secondRoot = root(second)
                if firstRoot != secondRoot {
                    parent[secondRoot] = firstRoot
                }
            }
        }

        // Inside each cluster, put every segment in the first lane where it fits.
        var laneOfSegment = [Int](repeating: 0, count: count)
        var lanesOfCluster: [Int: [[Int]]] = [:]
        for index in 0..<count {
            let cluster = root(index)
            var lanes = lanesOfCluster[cluster] ?? []
            var lane = 0
            while lane < lanes.count, lanes[lane].contains(where: { segments[$0].overlaps(segments[index]) }) {
                lane += 1
            }
            if lane == lanes.count {
                lanes.append([])
            }
            lanes[lane].append(index)
            lanesOfCluster[cluster] = lanes
            laneOfSegment[index] = lane
        }

        // Every lane of a cluster gets an equal share of the radius.
        let thickness = outerRadius - innerRadius
        var result: [DialSlice] = []
        for index in 0..<count {
            let laneCount = CGFloat(max(lanesOfCluster[root(index)]?.count ?? 1, 1))
            let lane = CGFloat(laneOfSegment[index])
            let band = thickness / laneCount
            result.append(DialSlice(
                segment: segments[index],
                innerRadius: innerRadius + band * lane,
                outerRadius: innerRadius + band * (lane + 1)
            ))
        }
        return result
    }

    /// The slice under a point given in polar coordinates (see `DialGeometry.polar`).
    static func slice(atHour hour: Double, distance: CGFloat, in slices: [DialSlice]) -> DialSlice? {
        let minute = Int(hour * 60)
        return slices.last { slice in
            slice.segment.contains(minute: minute)
                && distance >= slice.innerRadius - 0.04
                && distance <= slice.outerRadius + 0.02
        }
    }
}
