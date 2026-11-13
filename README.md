# 充电功率（ChargeMeter）

一个纯 SwiftUI 的 iOS App：显示电量、充电状态、充电速率（%/分钟）和**电池侧估算功率**。
无需越狱、无需任何权限、可直接上架。

## 能做什么 / 不能做什么

| | |
|---|---|
| ✅ 实时电量、充电/充满/未充电状态 | 来自 `UIDevice` 公开接口，5 秒刷新 |
| ✅ 充电速率（百分点/分钟）与充满剩余时间 | 最近 10 分钟做最小二乘拟合 |
| ✅ 估算功率（W） | 额定能量(Wh) × 速率(/h)，是**电池侧**平均功率 |
| ❌ 适配器协商功率 | iOS 不开放，需要越狱读 PMU |

所以数字会比充电头标称值低（中间有 buck 损耗、发热损耗），这是预期的。

## 打开方式

### 方式 A：XcodeGen（最快，推荐）

```bash
brew install xcodegen
cd ChargeMeter
xcodegen generate
open ChargeMeter.xcodeproj
```

然后在 Xcode 里选自己的 Team（Signing & Capabilities）、插上真机 ⌘R。
模拟器没有电池，只能看到"读取中…"。

### 方式 B：手动建工程

1. Xcode → File → New → Project → iOS → App
2. Product Name 填 `ChargeMeter`，Interface 选 **SwiftUI**，Language 选 **Swift**
3. 删掉模板生成的 `ContentView.swift` 和 `xxxApp.swift`
4. 把本目录 `ChargeMeter/` 下的三个 `.swift` 拖进工程（勾选 Copy items if needed）
5. 选 Team，真机运行

不需要改 Info.plist，也不需要加任何权限。

## 怎么用

- 插上充电器，看「≈ xx W」。第一次要等 1–2 分钟才出数（要先攒够采样点）
- 设置里把「电池额定能量」改成你机型的真实值，功率才准：
  iPhone 15 ≈ 13.0 Wh，15 Pro Max ≈ 17.1 Wh，16 ≈ 13.8 Wh
- 想比较两个充电头/两根线：同一个电量区间（比如 20%→50%）对比速率，比看瞬时瓦数可靠

## 代码结构

```
ChargeMeter/
├── ChargeMeterApp.swift     入口
├── BatteryMonitor.swift     采样、斜率拟合、状态机
└── ContentView.swift        环形电量、功率卡、曲线、设置
```

## 已知限制

- 后台不刷新：App 退到后台会暂停采样（iOS 限制），回前台会重新攒点
- 斜率是线性拟合，充电曲线本身是「先快后慢」，所以低电量段估得偏高，属正常
- 电池能量填错，功率就整体偏大或偏小，比例关系不变

## 可继续加

- 桌面小组件（WidgetKit）显示当前估算功率
- 历史记录持久化 + 多次充电对比
- Apple Watch 端
