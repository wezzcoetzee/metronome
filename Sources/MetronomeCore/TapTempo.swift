import Foundation

/// Averages the intervals between recent taps. A long pause starts a fresh measurement.
public struct TapTempo: Sendable {
    public var maxGap: TimeInterval = 2
    public var window = 4
    private var taps: [TimeInterval] = []

    public init() {}

    public mutating func tap(at time: TimeInterval) -> Int? {
        if let last = taps.last, time - last > maxGap {
            taps.removeAll()
        }
        taps.append(time)
        taps = Array(taps.suffix(window + 1))

        guard let first = taps.first, let last = taps.last, taps.count >= 2 else { return nil }
        let interval = (last - first) / Double(taps.count - 1)
        return Tempo.clamp(Int((60 / interval).rounded()))
    }
}
