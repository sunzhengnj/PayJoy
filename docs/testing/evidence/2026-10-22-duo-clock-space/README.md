# Duo 桌面钟可用空间修订

2026 年 10 月 22 日。原桌面钟以整个上半屏高度计算字号，入口只校验上方至少 120pt，没有扣除顶部按钮与相机避让。上方区域较矮或避让增加时，标签和时间可能超出上方区域。

当前入口与时间视图共用 `AdaptiveLayoutContext.deskClockTimeFontSize(in:)`。计算扣除相机顶部避让、44pt 按钮、20pt 标签、4pt 间隔与8pt底距后，为时间行预留字号的1.25倍高度；时间显示区左右各留16pt。只有容得下至少44pt字号且下方操作区可用时，才自动进入桌面钟。上方视图边界裁切限制过渡绘制范围，不改变专注会话或结算。

两项新增回归测试先在旧策略上实际失败：120pt上方区域不应进入；相机避让使原本可用的180pt上方区域变得不足。修订后完整临时 macOS 测试目标执行 **46 项、零失败**，其中9项专注、23项工资／工作日／本地化／输入、14项布局／滚动。46个测试方法体逐一与仓库原测试比对一致，四段生产布局／状态声明逐字抽取，业务文件直接链接；哈希及范围见 `manifest.json`。

原始输出为 `red.log`、`green.log`。复跑命令：

```sh
nice -n 20 swift test --package-path /Volumes/CodexOffload/Builds/PayJoyCoreAudit-3vc6zrqo --jobs 1
```

同一修订的低优先级、单任务通用 iOS Simulator `build-for-testing` 退出0，以 `TEST BUILD SUCCEEDED` 结束，见 `ios-build.log`。应用和测试均编译通过；只有未依赖 AppIntents 而跳过元数据提取的警告。Swift语法检查和 `git diff --check` 通过。

独立 reviewer 只读复核确认入口预算与实际视图接线一致、新测试覆盖有效边界，未发现新的确定性问题；它没有执行测试或构建。

本轮没有启动模拟器或应用，macOS测试不执行 iOS铰链、保留区域回调或SwiftUI界面恢复。真实字体度量、系统区域坐标、裁切、状态栏和空间不足后的回退画面，仍按[重启后实测清单](../../POST_RESTART_ACCEPTANCE.md)的D02验证。此证据不等于完整iOS XCTest、Duo视觉验收或iOS17运行回归。
