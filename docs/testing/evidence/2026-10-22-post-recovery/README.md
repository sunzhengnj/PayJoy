# 恢复卷上的候选构建与 Duo 启动观察

2026 年 10 月 22 日晚；全部为本次实际执行结果。

## 源码与构建

恢复卷已挂载到 `/Volumes/CodexOffload`。35 个源码／工程文件的 SHA-256 与下午离线打磨记录完全一致，构建结束后再次核对仍一致。

当前源码 Debug arm64 iOS Simulator `build-for-testing` 成功，退出0。主应用版本 **1.6(11)**，产物位于 `/Volumes/CodexOffload/Builds/PayJoyDuoRecovered/Build/Products/Debug-iphonesimulator/PayJoy.app`。使用低优先级、`-jobs 1`、Swift `-j1`；此轮未执行 iOS XCTest。唯一警告类型是未依赖 AppIntents 而跳过元数据提取。完整命令、编译输出见 `ios-build.log`，产物及日志哈希见 `manifest.json`。

## 第一轮：系统启动

只启动既有 PayJoy Verified Duo（iOS 27.1，24A94425），没有并行构建或安装开薪。20:12:40 宿主 CPU 空闲率63.36%、交换内存约5101 MiB；20:12:49、20:13:00、20:13:04 三次采样空闲率0%。20:13附近主动关闭，20:13:26空闲率恢复80.11%。这些是离散采样，不是连续性能曲线。

`duo-system-outer.png` 为系统桌面外屏，图标不完整。`bootstatus` 返回“Device already booted”未提供初始化进度。之后离线收集客体日志确认：SpringBoard 于20:12:54.862报告启动完成，20:12:56.631记录 `finishedStartup:YES` 并撤去启动遮罩，见 `boot-completed-excerpt.log`。设备中的迁移失败偏好最后修改于09:59:04，不能作为晚间新失败的证据。

## 第二轮：安装与启动当前应用

根据已完成系统启动的新日志，以及已经完成的候选包，单独验证安装和应用启动。20:18:47附近启动同一台Duo；`simctl install` 返回0，`simctl launch` 成功并返回PID47891。使用 `PAYJOY_SCREENSHOT_MODE PAYJOY_SCREENSHOT_SCREEN=featured-home` 演示夹具。

`duo-app-outer.png` 捕捉到开薪启动动画／启动页，尚未显示完整可交互首页。20:18:54、20:19:05、20:19:19 CPU空闲率仍为0%，因此再次主动关闭。20:19:44确认所有模拟器关闭、无遗留应用／安装／构建进程，CPU空闲率71.11%。这不代表系统自行崩溃，也不能证明设备最终无法完成初始化。

## 当前结论

已证明：源码对应、候选包可编译、Duo系统报告启动完成、当前应用可安装并创建进程。

未证明：系统长期稳定可交互、开薪完整首页、Duo四姿态、计时连续性、动效性能以及其余D01–D17验收。当前不放行E01或任何应用功能项。较长初始化观察须兼顾项目“持续高负载停止”的资源约束；不能以反复短观察中止替代完整启动验证。

系统诊断原件保存在本地 `/Volumes/CodexOffload/Builds/PayJoyDuoRecovered/Diagnostics`，未发送给Apple。

## 截图工具修订

发现原脚本先 `simctl boot` 再 `bootstatus -b`，后者可能直接返回“已经启动”，未监测启动过程。已改为由 `bootstatus -b` 启动并监测同一次启动，并在启动尝试前登记本任务的清理责任，确保启动失败后仍执行关闭。

命令替身测试先复现旧顺序失败（`capture-guard-red.log`），修订后通过（`capture-guard-green.log`）。补充迁移失败返回0和启动命令非零失败两条路径，均禁止继续安装／截图并执行关闭。测试不启动真实模拟器；启动状态完成仍不等于完整界面或性能验收，最终图片仍需人工审阅。

用户随后明确允许一次最多2分钟的高负载观察；其逐步结果单独保存在 `two-minute-observation/`，不能与上面短时观察混为一次。
