# 薪资全角小数输入修订

2026年10月22日。`LocalizedDecimalInput.sanitize` 原先仅识别与地区小数分隔符完全相同的字符；全角小数点或逗号被移除。生产清洗／解析链实测将日文地区的 `１２，３４５．６７` 和德文地区的 `１２．３４５，６７` 均变为1,234,567，而非12,345.67。德文地区的计薪天数 `２１，７５８` 则变为21,758，而非按两位小数规则得到21.75。

修订只在原清洗循环前统一字符宽度，再执行原有地区分隔符与小数位限制。`parse`、计薪计算和存储格式不变。

两项新增回归直接调用生产 `sanitize → parse`，在修订前实际得到上述三个错误值。修订后完整临时macOS目标执行 **51项、零失败**：12项专注／专注输入、25项工资／工作日／本地化／输入、14项布局／滚动；原有半角地区分隔符用例也通过。原始日志见 `red.log`、`green.log`，当前源码、方法及日志哈希见 `manifest.json`。测试方法逐项与仓库原方法比对，模块导入改为临时包名称，业务源文件直接链接。

复跑：

```sh
nice -n 20 swift test --package-path /Volumes/CodexOffload/Builds/PayJoyCoreAudit-3vc6zrqo --jobs 1
```

独立reviewer只读复核未发现新的确定性问题，确认改动发生在分隔符判断之前、地区规则和小数位限制保留、测试覆盖真实输入链。它没有执行测试或构建。

同一修订的低优先级、单任务通用iOS Simulator `build-for-testing` 退出0，以 `TEST BUILD SUCCEEDED` 结束，见 `ios-build.log`。Swift语法检查及 `git diff --check` 通过。

本轮未启动模拟器或应用。真实键盘、Duo开合时的草稿、预览与保存后重新打开的结果，仍按[重启后实测清单D13](../../POST_RESTART_ACCEPTANCE.md)验证。macOS测试不是完整iOS XCTest或设备验收。
