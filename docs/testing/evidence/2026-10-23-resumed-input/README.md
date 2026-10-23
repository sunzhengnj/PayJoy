# 恢复后的普通手机输入与工具检查

基线b996ed0，分支2.0.0，应用2.0.0(11)。本轮没有修改产品代码。Xcode27.1，普通iPhone iOS26.5。

- 旧源码专项执行新增的保存后页面高度断言：日文保存及高度通过；德文计薪天数字段被底部按钮挡住，测试的默认ScrollView.swipeUp落在键盘范围，字段无法滚入可编辑区域，最终几何断言失败。不能据此认定产品保存必然残留键盘占位。
- 将测试拖动限制在导航栏与保存按钮之间的可见内容区域，保留原始输入、尾部光标、完整清空与不穿透保存栏的断言。五项手机回归5/5通过：两地区薪资及计薪天数、显示切换不暂停、三种全角／混合时长、常亮重置、老板键引导重置。两地区保存后页面高度均恢复，SalarySettingsView.save未修改。
- 当前普通域14个PayJoy键在这五项测试前后字节一致。此前两键变化尚无确定根因；本轮未复现，不删除旧失败／恢复记录，也不把14键比较扩大为真实组件或App Group验收。原始业务快照仅在本机，比较摘要入Git。
- source-files.json为本轮UI编译时源码；build-flags.json核对实际Swift-j1及-num-threads1。应用／单元测试源码与此前Duo141/141、六项桌面钟和正常模式持久化成功运行一致；本轮未重复运行这几组，不宣称一次全部通过。
- 已按用户授权本地安装并注册XcodeBuildMCP2.7.0，独立MCP客户端完成initialize、tools/list、list_sims调用并正常关闭；见mcp-verification.txt。工具安装位于~/.codex/tools，未加入应用依赖。

原始结果：/Volumes/CodexOffload/Builds/PayJoySalaryViewportRed20261023R.xcresult（失败），/Volumes/CodexOffload/Builds/PayJoyPhoneInputsGreen20261023R.xcresult（5/5）。原片／日志保留本目录，不提交Git。完整Goal继续，下一项为Duo日历日期／导航往返及其余验收。

## Duo 日历连续性

新增testCalendarSelectionAndNavigationSurviveHingeChanges实际运行1/1通过（160.140秒），与上面的手机5/5是两次独立运行。由统计页进入工资日历，选中6月15日，经半折叠、旋转、展开、合上和再次展开后，日历标题与所选日期仍存在，未误入桌面钟，最后实际返回统计栈。六次Device Hub操作由cua_repl执行，执行后读取宿主UI，再原子写入匹配请求的ACK，见calendar-cua-events.jsonl。没有用伪造铰链代替真实模拟器操作。

日历结果包：/Volumes/CodexOffload/Builds/PayJoyCalendarContinuity20261023R.xcresult。全部显示器截图及原片留本地，以screenshot-index.json记录名称和哈希。横向双栏实拍中整月网格无需下滑，右侧显示当日明细与月度汇总；不能推广到所有月份／字号。部分XCTest其他显示器原图存在倒置／旋转；当前Device Hub纵向日历实拍方向正常，未据此改产品旋转逻辑，也不宣称已排除所有方向问题。

这组验证只覆盖代表日期和导航，尚未覆盖所有页面滚动锚点、日历草稿、输入法、所有主题／语言、短分区、隐私与性能。原141项单测与六项桌面钟的应用源码仍匹配；本轮产品实现未改变。原桌面钟验收计划继续保留未关闭范围，完整Goal保持active。MCP本轮实际完成设备枚举、Duo启动、原生UI快照、安装和启动应用；工具的一次手势成功回执没有造成可见滚动，不把回执当成可达性通过。
