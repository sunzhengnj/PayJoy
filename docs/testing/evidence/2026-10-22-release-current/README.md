# 当前源码 Release 离线核验

2026年10月22日。包含桌面钟空间预算、滚动连续性、专注全角输入与薪资全角小数修订的当前源码，免签名通用iOS设备Release构建成功。36个代码与构建元数据文件在构建前后哈希一致，见 `source-before.json`；最终命令、实际编译参数与日志哈希见 `manifest.json`。

## 产物检查

| 项目 | 结果 |
| --- | --- |
| 主应用与组件 | 均为1.6(11)，Mach-O最低iOS17.0、SDK27.1 |
| Duo API | `ArrangementView`、`GeometryProxy.reservedRegions`、`UIHingeInteraction`的11个相关外部符号均为弱引用；原始输出见 `duo-weak-symbols.txt` |
| 隐私清单 | 主应用和组件均已打包，与源码内容一致 |
| 资源 | 两个bundle均有 `Assets.car`；源码13处字面量图片引用均能对应目录中的资源，仅此范围通过，不覆盖动态键或视觉效果 |
| 本地化名称 | 英／日／韩为ClockJoy，简中为开薪，繁中及台／港为開薪 |
| 调试入口标记 | Release主二进制不含 `PAYJOY_SCREENSHOT_MODE`、`PAYJOY_DUO_TEST_POSE`字符串；源码中的对应开关由DEBUG条件保护 |

`artifact-check.json` 保存应用与组件二进制哈希、实际Mach-O版本、打包名称及检查边界。源码没有因本次核验而更改应用发布设置。

## 低资源构建

最终构建使用低优先级、一个构建任务，并通过当前Xcode的全模块优化并行设置关闭默认并行。实际Swift驱动命令的 `-j` 与全部 `-num-threads` 参数均为1，Duo编译标记保留。方法已记入仓库 `AGENTS.md`，以后核对最终命令，不仅看 `-jobs 1`。

首次构建虽通过，但Xcode在手动1线程参数后又追加了10线程默认值；该次不能证明单线程限制。尝试检查命令时，当前Xcode以退出64明确拒绝已不支持的 `-dry-run`，没有启动编译；最终按本机Swift构建规范修正设置，并重新构建成功。三次命令输出均保留，最终证据使用 `serial-build.log`。

## 验证边界

这是免签名Release编译产物，不是分发归档、App Store验证或上传。没有启动模拟器或手机应用；最低部署目标和弱引用不能证明iOS17运行正确，也不能证明Duo形态切换、页面裁切、帧率或能耗。设备项目仍按[重启后实测清单](../../POST_RESTART_ACCEPTANCE.md)执行，素材与最终归档继续等待设备验收。
