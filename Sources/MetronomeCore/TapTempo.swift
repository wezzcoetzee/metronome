import Foundation

struct TapTempo {
    private let maxGap: TimeInterval = 2
    private let window = 4
    private var taps: [TimeInterval] = []

    mutating func tap(at time: TimeInterval) -> Int? {
        if let last = taps.last, time - last > maxGap {
            taps.removeAll()
        }
        taps.append(time)
        taps = Array(taps.suffix(window + 1))

        guard let first = taps.first, let last = taps.last, taps.count >= 2 else { return nil }
        let interval = (last - first) / Double(taps.count - 1)
        return Int((60 / interval).rounded())
    }
}
