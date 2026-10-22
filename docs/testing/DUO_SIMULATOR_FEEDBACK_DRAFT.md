# iPhone Duo 模拟器初始化故障反馈草稿

2026 年 10 月 22 日。供 Apple Developer Support 或 Feedback Assistant 审阅，尚未提交。应用候选版本的 Duo 运行验收因此受阻；故障发生在系统初始化期间，相关探针没有安装或启动开薪。

## 故障与期望

单台 iPhone Duo 模拟器初始化时，宿主持续出现接近 0% CPU 空闲，`diskimagesiod` 在部分采样中达到约 315%–357%。一次带周期暂停的诊断返回 `DataMigrationFailed`；后续启动沿用此前迁移结果。其余受控观察因宿主高负载主动关闭设备，未完成启动。

期望系统完成初始化，进入可交互界面，以便验证真实折叠回调、展开双页与桌面钟。Apple 的 [Xcode 27.1 发行说明](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes)列出首次启动可能耗时数分钟。因此，受控观察提前关闭不能证明设备最终必然启动失败，也不能把该现象直接归因于应用。

## 环境

| 项目 | 当前值 |
| --- | --- |
| Mac | Mac16,10，16 GB 统一内存 |
| macOS | 27.0.1，26A434 |
| Xcode | 27.1，27A9275 |
| Duo 运行时 | iOS 27.1，24A94425，Ready／Verified |
| 当前运行时登记 | `2F27E9A4-1309-4303-A4AF-9452FA479668` |
| 主要诊断设备 | PayJoy Verified Duo，`A199B0FE-1420-4D85-A191-5E91A9C10FCF` |
| 并发情况 | 每次探针仅一台模拟器，无并行构建 |

本次离线检查时所有模拟器均关闭，没有构建、测试或 `launchd_sim` 进程。宿主已连续运行约 22 天，交换内存使用约 11.4 GiB；一次 CPU 抽样为 44.63% 空闲。内存和 CPU 快照是当前环境背景，不能证明故障因果关系。原始版本、设备、进程与运行时检查保存在 [offline-recheck.json](evidence/2026-10-22-duo-startup/offline-recheck.json)。

## 已观察路径

1. 在 Device Hub 选择既有 Duo，点击 Start；或对同一设备执行 `xcrun simctl boot <UDID>`。没有同时启动其他设备或运行应用构建。
2. 使用 `xcrun simctl bootstatus <UDID>` 观察。初始化曾推进至 BackBoard、LaunchServices 和 MobileSafari 数据迁移。
3. 持续观察宿主负载。达到本任务保护阈值时执行 `xcrun simctl shutdown <UDID>`，保留设备数据。

以上是历史观察路径，本次没有重新执行。已初始化多次的设备不是全新安装复现；没有独立取得一个不干预时序、完整等待数分钟的失败样本。

## 系统日志证据

同一段客体日志显示：

- 09:58:32.173：迁移进度窗口开始展示。
- 09:58:58.520：BackBoard 的 CoreAnimation Render 记录 `synchronize timed out`。
- 09:59:03.878：迁移遥测中 `pluginCrashCount`、`pluginWatchdogCount`、`pluginReturnedFalseCount` 均为 0；随后报告 `Reporting migration failure due to migration progress window incident`。
- 09:59:03.881：BackBoard 收到迁移未成功的结果。
- 10:06:52.386：后续启动报告系统版本未变、无需迁移。该次返回的失败不能作为新的迁移插件失败样本。

渲染超时先于迁移窗口失败，适合作为排查窗口／渲染路径的线索；现有日志不能证明两者存在因果关系。09:59 这次诊断曾使用 SIGSTOP／SIGCONT 节流，会影响系统时序，必须连同结果披露。

带原始行号的短摘录见 [migration-excerpt.log](evidence/2026-10-22-duo-startup/migration-excerpt.log)。源日志与摘录的 SHA-256 保存在 `offline-recheck.json`；完整客体日志归档仍在本机：

`/Volumes/CodexOffload/Builds/PayJoyDuoStatic/duo-guest-collected-2026-10-22.logarchive`

## 已完成的排除与恢复

| 检查 | 结果与边界 |
| --- | --- |
| 运行时签名 | 原 Apple Cryptex 资源曾返回 `-67054`。当前以原字节不变的官方签名 DMG 恢复登记并通过验证，启动负载仍未解决 |
| 设备登记 | 刷新旧用户级 CoreDeviceService 后，Device Hub／devicectl 可见 Duo 从 0 台恢复为 3 台；没有清除设备 |
| 旧服务引用 | 刷新 CoreSimulatorService 后释放已清理运行时的过期文件引用；不等于已修复启动 |
| 内外屏取图 | 合上时默认内屏为黑色，显式外屏取图显示 Apple 启动画面。黑色内屏不能独立证明启动失败 |
| 优先级与缓存预读 | 降低进程优先级及预读缓存未消除启动峰值；不能据此确定唯一根因 |
| 无压缩镜像对照 | 转换副本因缺少 Apple 镜像签名被拒绝，未用于启动；性能假设未得到检验。原签名运行时已恢复，临时副本已清理 |

详细遥测和回退经过见 [启动记录](evidence/2026-10-22-duo-startup/summary.json)及[镜像实验记录](evidence/2026-10-22-runtime-encoding/summary.json)。没有修改迁移结果偏好、绕过签名、擦除或删除模拟器。

## 请求协助定位

请确认该版本在 Duo 首次初始化时是否存在已知的迁移进度窗口／CoreAnimation 同步问题，以及适用的官方修复版本或恢复步骤。希望恢复既有设备数据，并在 16 GB 宿主上完成初始化，避免通过伪造迁移成功或关闭系统组件绕过问题。

如需进一步采样，请明确所需日志类别、持续时间及工具。现有归档包含宿主路径和系统活动；向外提交时由用户审阅附件范围。本草稿不触发提交或上传。
