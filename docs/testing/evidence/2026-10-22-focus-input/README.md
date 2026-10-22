# 自定专注时长输入修订

2026年10月22日。原自定时长直接使用 `Int(customMinutes)`，全角数字及首尾空白均无法解析，界面只显示横线并禁用开始。

当前由 `FocusSession.customMinutes(from:)` 解析输入副本：去除首尾空白、转换全角为半角，再作完整整数解析及1–240分钟范围校验。输入框仍绑定原始字符串，不回写规范化内容。准备页、桌面准备页与开始会话的范围判断共用 `durationMinuteRange`；自定输入区补上五语言整数范围提示。新成员为静态属性／方法，未新增持久化字段、数据迁移或公开API。

新增三项输入测试覆盖全角／混合宽数字、首尾空白、非法／越界／溢出输入。机械抽取旧整数解析及原范围判断后，12项专注测试出现六个断言失败，分别是全角和空白输入；非法与越界测试正常。修正后完整临时macOS目标执行 **49项、零失败**：12项专注／专注输入、23项工资／工作日／本地化／输入、14项布局／滚动。现有静态翻译键与参数扫描通过。

`red.log`、`green.log` 保存原始输出；`manifest.json` 保存当前源码、测试方法及日志哈希。测试方法体逐项与仓库原方法比对，除模块导入外保持原样；生产业务文件直接链接，布局／状态声明逐字抽取。复跑：

```sh
nice -n 20 swift test --package-path /Volumes/CodexOffload/Builds/PayJoyCoreAudit-3vc6zrqo --jobs 1
```

独立reviewer只读复核未发现新的确定性问题，确认解析未修改草稿、范围与原业务guard等价、四种非简中翻译保留两个顺序一致的参数。它未执行测试或构建。

同一修订的低优先级、单任务通用iOS Simulator `build-for-testing` 退出0，以 `TEST BUILD SUCCEEDED` 结束，见 `ios-build.log`。只有未依赖AppIntents而跳过元数据提取的警告。Swift语法检查与 `git diff --check` 通过；编译期间一次CPU抽样约63%空闲。

本轮未启动模拟器或应用。macOS测试不执行完整AppState／SwiftUI交互；真实输入法、键盘、五语言提示排版以及Duo开合时的草稿和焦点，仍按[重启后实测清单D12](../../POST_RESTART_ACCEPTANCE.md)验证。
