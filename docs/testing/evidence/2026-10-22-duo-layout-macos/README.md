# Duo 布局决策执行证据 · 2026-10-22

现有 `TabChromeLayoutTests.swift` 的 7 个测试方法在 macOS 原生 XCTest 中实际执行，全部通过。测试文件只更换模块导入；没有改写断言。覆盖双页内容净宽、安全区占位、横向折痕触发、操作区相机遮挡与桌面钟状态优先级。

临时包：`/Volumes/CodexOffload/Builds/PayJoyCoreAudit-3vc6zrqo`。
复跑：`nice -n 20 swift test --package-path /Volumes/CodexOffload/Builds/PayJoyCoreAudit-3vc6zrqo --jobs 1 --filter TabChromeLayoutTests`。

生产 `AdaptiveLayoutContext`、`TabChromeOccupancy`、`TabChromeLayout`、`DeskClockMode` 声明逐字抽取至临时目标；工资／专注模型与完整 `AppTheme.swift` 直接链接生产源码，没有常量或业务替身。抽取边界、源码及块哈希见 `manifest.json`，原始输出见 `tests.log`。这不执行 iOS 专属的 `reservedRegions`／`UIHingeInteraction`，也不验证 SwiftUI 画面、触控和形态切换。

同轮首页桌面钟增加系统黑白外观偏好，防止黑底沿用浅色页面的状态栏配色。单任务通用 iOS Simulator `build-for-testing` 成功；未执行 iOS XCTest，状态栏视觉仍待 Duo 实拍。
