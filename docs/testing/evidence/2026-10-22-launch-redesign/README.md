# 全机型系统启动页重设计

2026-10-22，Debug 1.6(11)，最低版本仍为 iOS 17。

以原生字标、奶油底和黄色短线替换居中的方形人物位图。使用系统 LaunchScreen.storyboard，宽度限制与安全区约束适用于不同屏幕；启动页不引入计时器、假进度或人为停留。简体显示「开薪！」、繁体显示「開薪！」，英文／日文／韩文显示 ClockJoy。系统启动页使用系统语言，应用内语言偏好继续由已有逻辑处理。

## 实测

- `build.log`：当前源码和新启动资源构建成功，无 storyboard 警告。
- `duo-signed-launch.png`、`duo-portrait-signed-launch.mov`：Duo iOS 27.1 内屏竖向冷启动实拍。
- `duo-closed-launch.png`：Duo 外屏横向冷启动实拍。
- `iphone-launch.png`：普通 iPhone（1170×2532，iOS 26.5）英文系统冷启动实拍。
- `*-home-after-launch.png`：同包正常进入首页。仅为启动冒烟检查，不等于全功能回归。
- 所有本地化 strings 均经 ibtool 编译；繁体、日文、韩文未逐项进行系统语言切换实拍。iOS 17 实机／运行时仍缺，未声称实测通过。

初次免签名构建的启动资源被 SplashBoard 拒绝，错误 -67056；`unsigned-resource-validation-failure.*` 保留诊断。对本地模拟器产物及内嵌组件进行 ad-hoc 签名、重新安装后取得有效实拍。未更改发布签名设置，也未卸载或清除模拟器数据。

本次只改启动资源与项目引用；应用逻辑沿用此前 134 项 XCTest 通过的版本。完整 Duo 连续性仍见 ../2026-10-22-inner-layout/README.md 和 ../../POST_RESTART_ACCEPTANCE.md。

参考：[Apple 启动页配置](https://developer.apple.com/documentation/xcode/specifying-your-apps-launch-screen)。
