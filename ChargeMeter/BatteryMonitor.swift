import UIKit
import Combine

/// 一次采样：时间 + 电量百分比
struct Reading: Identifiable {
    let id = UUID()
    let date: Date
    let percent: Double
}

/// 只依赖公开 API：UIDevice.batteryLevel / batteryState
final class BatteryMonitor: ObservableObject {

    @Published private(set) var percent: Double = 0
    @Published private(set) var isCharging = false
    @Published private(set) var isFull = false
    @Published private(set) var isKnown = false

    /// 充电速率，单位：百分点 / 小时（正数表示在涨）
    @Published private(set) var ratePerHour: Double = 0
    @Published private(set) var readings: [Reading] = []

    private var timer: Timer?

    /// 只保留最近 10 分钟的数据算斜率
    private let window: TimeInterval = 600

    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        // 插拔电源时立刻刷新，不等 5 秒
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
    }

    deinit { timer?.invalidate() }

    func sample() {
        let device = UIDevice.current
        let raw = device.batteryLevel

        if raw >= 0 {
            isKnown = true
            percent = Double(raw) * 100
            readings.append(Reading(date: Date(), percent: percent))
            let cutoff = Date().addingTimeInterval(-window)
            readings.removeAll { $0.date < cutoff }
            updateRate()
        }

        switch device.batteryState {
        case .charging:
            isCharging = true
            isFull = false
        case .full:
            isCharging = true
            isFull = true
        case .unplugged:
            isCharging = false
            isFull = false
        default:
            isCharging = false
            isFull = false
        }
    }

    /// 最小二乘斜率 → 换算成 百分点/小时
    private func updateRate() {
        guard readings.count >= 3,
              let first = readings.first,
              let last = readings.last,
              last.date.timeIntervalSince(first.date) >= 60
        else {
            ratePerHour = 0
            return
        }

        let t0 = first.date.timeIntervalSince1970
        let xs = readings.map { $0.date.timeIntervalSince1970 - t0 }
        let ys = readings.map { $0.percent }
        let n = Double(readings.count)
        let sumX = xs.reduce(0, +)
        let sumY = ys.reduce(0, +)
        let sumXY = zip(xs, ys).reduce(0) { $0 + $1.0 * $1.1 }
        let sumXX = xs.reduce(0) { $0 + $1 * $1 }

        let denom = n * sumXX - sumX * sumX
        guard abs(denom) > 1e-9 else { ratePerHour = 0; return }

        let slopePerSecond = (n * sumXY - sumX * sumY) / denom
        ratePerHour = slopePerSecond * 3600
    }

    /// 距离充满还要多久（分钟）
    func minutesToFull() -> Double? {
        guard isCharging, !isFull, ratePerHour > 0.1, percent < 100 else { return nil }
        return (100 - percent) / ratePerHour * 60
    }
}
