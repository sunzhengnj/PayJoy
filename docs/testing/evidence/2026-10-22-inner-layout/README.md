# Duo 内屏纵向与半折叠布局修订

2026-10-22，Xcode 27.1 / iOS 27.1，PayJoy Verified Duo，Debug 1.6(11)。

## 已修复并验证

- 高窗口仅凭宽度进入双列，系统横向 Arrangement 隐去右页：布局策略增加高宽条件；真实竖向内屏首页回到完整单列。
- 首页宽卡片被拉伸、人物气泡远离插画：单列内容限宽 560pt，插画区域限宽 360pt。
- 单列滚动在安全区边缘被硬切：只在没有折痕／遮挡的屏幕边缘延展裁切范围；已拖动到首页底部，收工按钮在标签栏上方完整可达。
- 书本半折叠的运行中专注挤在左屏：左侧时间、右侧暂停／结束；旋转为桌面姿态后变成上方时间、下方操作，使用同一个会话来源。
- Duo 初始化／收起专注不再请求强制方向，普通 iPhone 的手动旋转路径保留。

## 证据

`portrait-red.log` 为新布局用例修复前的真实 XCTest 失败；`final-ios-tests.log` 和 `final-test-summary.json` 为修复后 134 项真实 iOS XCTest 全通过，零失败、零跳过。结果包在 `/Volumes/CodexOffload/Builds/PayJoyInnerLayoutFinal.xcresult`。

`final-home-portrait*` 是修复后的内屏竖屏及滚动底部画面；`final-focus-book*` 与 `final-focus-tabletop*` 是同一次运行中专注的书本／桌面姿态。带 `window` 的图包含 Device Hub 的实际折叠外形。`focus-book-before.png` 保留原来右半屏空白的问题。

这些画面使用冻结业务时钟的截图夹具，只证明布局和形态切换，不证明真实时间经过、截止结算或业务数据持久化。非 `final-` 图片是修订过程证据，不能代替最终画面。

## 未完成

专注准备／结果页仍使用单个安全分区，书本姿态的空间利用仍需打磨；全页面草稿、日期、独立滚动位置与折叠连续性、更多折叠角度和相机遮挡仍需实测。D01/D07 不标为完整通过。
