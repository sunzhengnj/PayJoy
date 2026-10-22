# 精选候选画面（审阅中）

这里保存从当前应用构建直接截取的原始画面。`qa/` 是审查证据，**不是待上传素材**；只有最终构建、文案、状态和设备规格一致后，才把通过审查的画面放入 `raw/`。

## 画面顺序

| 序号 | 画面 | 需要讲清的体验 | 当前状态 |
| --- | --- | --- | --- |
| 1 | 普通 iPhone 首页、专注准备、计时（Dynamic Island 中尺寸） | 工作日进度、25／45／自定与预计结束时间、纯色单时间计时 | **本次提交必需设备组**；目前无最终构建截图，须先补至少一张并审查整组叙事 |
| 2 | 普通 iPhone 6.9 英寸补充组 | 用较大画幅呈现同一条专注到下班故事 | 早期 Debug 图已归入 QA；待最终候选构建复拍，不能代替中尺寸必需组 |
| 3 | Duo 展开今日双页 | 左页进度、右页动作，共用同一份状态 | 运行时 Ready／Verified，当前 Debug 已取得双页和真实计时实拍；最终候选构建仍需冻结后复拍 |
| 4 | Duo 桌面钟 | 上方远看单一时间，下方完成操作 | 已有半折叠与真实形态切换 QA；待最终候选构建复拍 |
| 5 | Duo 产品页 App Preview | 纯应用内画面展示双页、桌面钟与同一段专注 | 待 Duo 设备验收后录制；横屏按 1920×886、竖屏按 886×1920 导出并在 App Store Connect 预览 |

## 规格与核验

[Apple 截图规格](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)要求 iPhone 的 Dynamic Island **中尺寸**设备组至少一张，可用 1179×2556 或 1206×2622 竖屏（或对应横屏）；每组可上传 1–10 张 JPEG／PNG，不能包含 Alpha 通道。6.9 英寸大尺寸组可用 1320×2868，但不能用它替代前述必需组。Duo 外屏为 1398×2034，内屏为 2007×2853（横向时对调）。[Apple 精选说明](https://developer.apple.com/app-store/getting-featured/)强调连贯的体验、设计、创新、本地化及有说服力的产品页；这套画面围绕“看今天 → 开始一段 → 摆下继续 → 收下今天”组织。用户已明确本版不以无障碍兼容作为验收门槛。

[Apple 的 App Preview 规格](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications)已包含 Duo：接受 886×1920 或 1920×886，15–30 秒，最高 30 fps。App Preview 只取应用内画面；实体设备开合留作提名辅助链接。Duo 截图在 2026 年这次提交并非强制项，但提交后产品页可显示 Duo 优化标识，因此仍是本候选版的重要交付物。

`qa/2026-10-17-initial-iphone-6.9/` 来自 Xcode 27.1 Debug 1.5 (10)、iOS 26.5 iPhone 17 Pro Max，状态栏固定为 15:24。三张均为 1320×2868、无 Alpha。首轮发现：首页在 15:24 显示“加班中 39m”，不适合讲普通工作日；专注准备页是直接展示的内部夹具，和真实标签导航不一致。因此这组只用于发现问题，不上传。

首页与专注准备页曾用同一 Debug 构建复拍，均为 1320×2868、无 Alpha，状态栏和五个真实标签完整。当前代码已继续改动，首页图移入 `qa/2026-10-17-home-pre-candidate/` 留作审查证据；专注页加入预计结束时间后，旧图移入 `qa/2026-10-17-focus-before-end-time/`。两张均须用最终候选构建重拍，目前 `raw/` 没有通过审查的上传图。`qa/2026-10-17-duo-boot-failure/featured-home-black.png` 是 Duo 数据迁移失败时产生的全黑内屏图，只用于排查，不能上传。

后续诊断确认原 iOS 27.1 运行时签名校验失败（`-67054`）。从本机已下载的安装包原始 DMG 注册的新运行时显示 `Ready / Verified`；10 月 22 日刷新 CoreSimulator 服务后，未重现旧 `liblaunch_sim.dylib` 加载错误。随后发现 CoreDeviceService 沿用旧设备列表，刷新后 Device Hub 已识别三台已有 Duo，未新建设备或清除数据。早期启动曾被高负载保护主动中断；用户后来撤销该规则，当前单台 Duo 已正常进入应用，并完成真实专注／到下班流程。最多同时两台、一个构建或测试任务继续有效。实测中仍有重新打开内屏的短暂黑屏待排查，不能由当前 QA 直接放行最终素材。

`capture.sh` 批量采集需显式设置 `PAYJOY_CAPTURE_HOST_READY=1`，这表示主机已能稳定完成采集，不是另一次启动授权。脚本在有构建／测试运行时中止，优先复用已启动的指定测试机；指定机未启动时，检查两台上限，再通过 `bootstatus -b` 启动并监测。该次启动报告数据迁移失败时会在安装前中止，需另行检查实际应用就绪状态。清理时总会清除本次设置的状态栏覆盖，只关闭脚本自己尝试启动的设备；复用的既有设备由调用者管理。启动监测成功及固定等待时间均不能证明截图已经显示完整应用，所有采集画面仍须逐张审阅。示例（仅在已确认的测试主机运行）：

```sh
PAYJOY_CAPTURE_HOST_READY=1 \
marketing/app-store/featured-candidate/capture.sh DEVICE_ID \
  DerivedData/Build/Products/Debug-iphonesimulator/PayJoy.app \
  marketing/app-store/featured-candidate/raw/zh-Hans/iphone-6.9 \
  featured-home featured-focus-tab focus-running
```

`focus-running` 会由 Debug 的 `ScreenshotHostView` 创建固定 18 分 42 秒会话，可用于静态画面审查；它不能证明真实倒计时、到点结果或折叠连续性，这些须在设备上真实开始同一段会话后交互录制。复拍后逐张检查设备像素尺寸、状态栏与应用时钟、收入和工作状态、按钮与折痕位置、语言文本、完整画面和隐私。最终素材需从同一候选构建导出，并与提名文案逐句对应。

脚本会按静态夹具分别设置状态栏时间：凌晨首页 00:18、周末回顾 19:24、其余画面 15:24；这些时间只用于静态截图，真实连续录屏仍须保留设备实际时间。`test_capture_safety.sh` 用命令桩检查主机就绪、构建互斥、两台上限、既有测试机复用／归属清理和这三个时间，不会启动模拟器。

Duo 取屏时先用 `xcrun simctl io DEVICE_ID enumerate` 核对屏幕：当前测试机 `primary` 是 1398×2034 外屏，`primary-1` 是 2007×2853 内屏；通过 `PAYJOY_CAPTURE_DISPLAY=primary` 或 `primary-1` 明确指定，并用 Device Hub 确认姿态。10 月 22 日合上状态的默认内屏截图全黑，而外屏显示 Apple 启动画面，因此单张黑图不能独立证明启动失败。两张均未显示应用，不是最终素材。Xcode 27 使用 [Device Hub](https://developer.apple.com/documentation/xcode/managing-your-simulated-and-physical-devices-in-device-hub) 查看设备，不依赖旧的 `Simulator.app` 路径。
