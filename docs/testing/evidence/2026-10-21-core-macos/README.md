# 纯模型 XCTest：2026-10-21

最新结果：**32 项通过，0 失败**。原始输出见 [core-localization-tests.log](core-localization-tests.log)，当前源码与原测试方法的 SHA-256、方法清单和基准 Git 修订见 [localization-manifest.json](localization-manifest.json)。先前的 26 项纯模型运行仍保留在 [core-tests.log](core-tests.log) 与 [manifest.json](manifest.json)，对应文案修正前的源码哈希。工作树尚未提交，不能只用 Git 修订号识别本次测试代码。

本次在 arm64 macOS 上执行 XCTest，未启动 iOS 模拟器。覆盖 9 项专注会话测试及 17 项工资／工作日计算测试，包括暂停恢复、持久化、仅结算一次、跨午夜、固定下班截止时间、下一工作日与手动日历调整、午休、休息日、提前收工和加班汇总。它不覆盖 AppState、通知授权与异步调度、Live Activity、SwiftUI、Duo 形态、系统旋转或 iOS 17 运行行为，也不是完整 iOS 测试套件通过的证明。

新增执行的六项现有测试覆盖核心文案、界面源码翻译与格式参数、地区语气、会员展示名称、区域小数输入及无效薪资设置归一化。源码扫描实际读取应用 26 个与组件 4 个 Swift 文件；其结果只说明已识别的静态键与参数检查通过，不证明所有动态文案或实际排版都正确。真实扫描曾发现实时活动文案源键缺少 `%@`，以及测试将英文百分比误判为格式参数，失败输出保留在 [core-localization-before-fix.log](core-localization-before-fix.log)。两处修正后重跑通过，扫描测试同时加入了非空断言。

临时 Swift Package 位于 `/Volumes/CodexOffload/Builds/PayJoyCoreAudit-3vc6zrqo`。生产目标通过符号链接直接使用首份 `manifest.json` 列出的六个生产源码文件，没有模型替身或逻辑拷贝。测试目标从现有两个 XCTest 文件选取清单中的原方法，保留原有 `setUp` 和日期辅助方法；仅把导入模块名从 `PayJoy` 改为 `PayJoyCore`，并排除依赖 iOS/AppState 的方法。已逐项比对最新 32 个测试方法体与原文件完全一致，方法哈希写入清单。源码扫描的目录必须是真实目录，目录内逐个链接源码文件；Foundation 不遍历作为根入口的目录符号链接，不能使用该方式搭建扫描夹具。

在源码哈希仍一致且本地临时包存在时，可重新运行：

```sh
nice -n 20 swift test -j 1 --disable-swift-testing \
  --package-path /Volumes/CodexOffload/Builds/PayJoyCoreAudit-3vc6zrqo
```

复核时应先遵守项目的进程与负载限制。源码变化后，本目录只能证明记录时的版本；最终候选版仍需重跑完整 iOS 测试及设备验收。
