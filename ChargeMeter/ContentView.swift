import SwiftUI
import Charts

struct ContentView: View {
    @StateObject private var monitor = BatteryMonitor()
    @AppStorage("batteryWh") private var batteryWh: Double = 17.0
    @State private var showSettings = false

    /// 电池侧估算功率：额定能量(Wh) × 每小时充进的电量比例
    private var estimatedWatts: Double? {
        guard monitor.isCharging, monitor.ratePerHour > 0.1 else { return nil }
        return batteryWh * monitor.ratePerHour / 100
    }

    private var ratePerMinute: Double { monitor.ratePerHour / 60 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    gaugeCard
                    powerCard
                    if monitor.readings.count >= 3 { chartCard }
                    footnote
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("充电功率")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(batteryWh: $batteryWh)
            }
        }
    }

    // MARK: 卡片

    private var gaugeCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 14)
                Circle()
                    .trim(from: 0, to: max(0.001, min(1, monitor.percent / 100)))
                    .stroke(
                        monitor.isCharging ? Color.green : Color.orange,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.6), value: monitor.percent)

                VStack(spacing: 2) {
                    Text("\(Int(monitor.percent.rounded()))%")
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Image(systemName: monitor.isCharging ? "bolt.fill" : "bolt.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 150, height: 150)

            Text(stateText)
                .font(.headline)
                .foregroundStyle(monitor.isCharging ? Color.green : Color.secondary)

            if let eta = monitor.minutesToFull() {
                Text("预计 \(formatMinutes(eta)) 充满")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    private var powerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(estimatedWatts.map { String(format: "≈ %.1f", $0) } ?? "—")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(estimatedWatts == nil ? Color.secondary : Color.primary)
                Text("W")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack {
                metric("充电速率", String(format: "%+.2f %%/分", ratePerMinute))
                Divider().frame(height: 32)
                metric("换算基准", String(format: "%.1f Wh", batteryWh))
            }
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近 10 分钟电量")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Chart(monitor.readings) { reading in
                LineMark(
                    x: .value("时间", reading.date),
                    y: .value("电量", reading.percent)
                )
                .interpolationMethod(.monotone)

                AreaMark(
                    x: .value("时间", reading.date),
                    y: .value("电量", reading.percent)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(.linearGradient(
                    colors: [.green.opacity(0.25), .clear],
                    startPoint: .top, endPoint: .bottom
                ))
            }
            .chartYScale(domain: yDomain)
            .chartXAxis(.hidden)
            .frame(height: 150)
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    private var yDomain: ClosedRange<Double> {
        let values = monitor.readings.map(\.percent)
        let lo = max(0, (values.min() ?? 0) - 2)
        let hi = min(100, (values.max() ?? 100) + 2)
        return lo < hi ? lo...hi : 0...100
    }

    private var footnote: some View {
        Text("功率是按「电池额定能量 × 充电速率」估算的电池侧平均值，不含充电头到电池之间的损耗，通常低于适配器标称输出。iOS 不向 App 开放电压/电流读数，所以无法给出适配器协商功率。")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
    }

    // MARK: 小组件

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.medium)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stateText: String {
        if !monitor.isKnown { return "读取中…" }
        if monitor.isFull { return "已充满" }
        if monitor.isCharging { return "正在充电" }
        return "未充电"
    }

    private func formatMinutes(_ minutes: Double) -> String {
        let total = Int(minutes.rounded())
        if total < 60 { return "\(total) 分钟" }
        return "\(total / 60) 小时 \(total % 60) 分"
    }
}

struct SettingsView: View {
    @Binding var batteryWh: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $batteryWh, in: 5...40, step: 0.5) {
                        HStack {
                            Text("电池额定能量")
                            Spacer()
                            Text(String(format: "%.1f Wh", batteryWh))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("iPhone 15 ≈ 13.0 Wh，iPhone 15 Pro Max ≈ 17.1 Wh，iPhone 16 ≈ 13.8 Wh。填得越准，估算功率越准。")
                }

                Section("说明") {
                    LabeledContent("数据来源", value: "UIDevice 公开接口")
                    LabeledContent("刷新频率", value: "5 秒")
                    LabeledContent("权限", value: "无需任何权限")
                }
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
