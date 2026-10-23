# Duo 原生输入、展开薪资表单与专注显示回归

2026-10-23，开发分支2.0.0，应用2.0.0(11)，Xcode27.1（27A9275），Duo iOS27.1（24A94425），设备A199B0FE-1420-4D85-A191-5E91A9C10FCF。基线见base-commit.txt；末次源文件哈希见final-source-files.json。

## 已修及验证方法

- 薪资输入保留键盘正在编辑的原文，使用规范化副本更新计算草稿；取消在onChange中反写字段。原实现完整清空后输入日文全角金额，点击保存再打开仍为12（应为12345.67）。只去掉回调里的提前返回也未修复，原片显示输入过程已缩成12。最终日文、德文原文输入及保存回读均通过；计薪天数保留两位小数规则21.75。
- 薪资／首次完整设置将计薪天数放在右侧，与发薪日和计算预览组成一组；左侧仅保留薪资类型与金额。紧凑布局顺序仍为类型→金额→天数→发薪日，使用同一字段及滚动层级。展开首屏已审阅；其他姿态仍需专项。
- 计薪天数加减按钮原本虽有44pt布局，原生查询只测得13pt图标点击区。为44pt标签补充矩形contentShape后，两个按钮均可点击、完整位于首屏滚动视口内，宽高至少44pt。
- 新增独立PayJoyUITests目标和scheme。用真实字段、键盘输入、开始和保存按钮回归；不读取剪贴板，不在发布目标增加测试入口。专注２５、2５、　４５　分别开始25／25／45分钟；0、241、25.5、25 minutes均禁用开始且不创建会话。

## 专注显示的边界

显示“距下班”与专注可同时进行。正常计时逻辑只在暂停按钮动作中调用pauseFocus，时间菜单仅修改展示状态。此前[真实会话](../2026-10-23-duo-focus-review/README.md)已核对切换前后会话、截止和暂停字段；本轮另加原生菜单交互回归：从开始专注后切到距下班，再切回本段剩余，两次均保留暂停按钮且没有继续按钮。截图模式的时钟刷新受限，这项只证明交互和运行状态，不代替此前正常模式的真实计时连续性。

最初featured-focus-tab样例继承了通用样例的进行中加班，按业务规则没有时间切换入口。此次只从该Debug样例中移除加班，正常模式规则不变。样例修正后原生层级显示时间菜单为Button；之前日志中的PopUpButton类型提示来自另一个设置菜单，不能直接套用。中间失败均留在结果包与执行计划中。

## 证据范围与仍待完成

Save→返回个人页→重新进入薪资设置验证当前AppState中的保存结果。再次以截图模式启动会重置样例，不能作为正常模式保存→进程重启→持久化恢复的通过证据。本轮没有将旋转称为真实折叠，也没有验证全部姿态、软键盘、焦点或普通iPhone；实际折叠和正常模式持久化仍在执行计划Task2及D12／D13／D15中保持待测。

此前一次原生输入运行记录了“Invalid frame dimension (negative or non-finite)”运行警告，结果包没有给出源码位置，见frame-warning-issues.json；未据此加入猜测性的边界补丁，继续保留待定位。

截图需枚举XCUIScreen.screens；display0是本轮未使用的外屏，display1为实际内屏。XCUIApplication.frame的长宽不能证明Duo当前内屏形态；边界断言比较真实ScrollView和控件。原始截图、录像、合成事件和结果包均留本机，Git只保存说明、摘要和证据索引。

## 运行记录

- 原始回调RED：/Volumes/CodexOffload/Builds/PayJoySalaryUIClearOriginal20261023.xcresult，保存回读12；其旧版形态断言使用app.frame，已改用视口边界。
- 仅同步草稿的失败尝试：/Volumes/CodexOffload/Builds/PayJoySalaryUIDraftSync20261023.xcresult，仍保存12；按钮13pt。
- 保留输入原文后：/Volumes/CodexOffload/Builds/PayJoyInputUIPreserveDraft20261023.xcresult，四项输入／布局用例通过，额外显示切换用例因样例未提供菜单而失败；不能将该结果包称为全套通过。
- 末次输入／布局运行：/Volumes/CodexOffload/Builds/PayJoyInputUIFinal20261023.xcresult，四项输入／布局通过；显示专项因测试把Button查询成PopUpButton而失败。仅修正该专项的查询后，同源单项重试通过：/Volumes/CodexOffload/Builds/PayJoyFocusDisplayUICleanLaunch20261023.xcresult，1通过、0失败、0跳过。两份结果分别见input-regression-*和display-regression-*，不合并伪装成一次全绿UI运行。
- 期间另一次专项点按开始后未出现会话，快照仍为准备页；没有查到原应用残留进程。随后相同源码重试通过。尚未证明该偶发点按／启动现象的原因，不将其写成应用问题已修复。
- 当前源码完整139项iOS XCTest通过、0失败、0跳过，结果包/Volumes/CodexOffload/Builds/PayJoyInputUnit20261023.xcresult，见unit-summary.json。
- verify-results.py核对四项UI通过、一次显示切换单项通过、原失败保留、139项结果和当前源文件哈希。完整Goal继续以[总验收清单](../../POST_RESTART_ACCEPTANCE.md)为准。

构建采用低优先级、一项构建任务，命令行Debug WMO关闭并行，核对实际-j1及所有-num-threads 1，见compiler-flags.json。仅使用一台Duo。日常UI回归显式关闭额外全量诊断采集，保留针对性日志与结果包；此前取消／失败遗留的两项simctl diagnose已按PID确认后清理。

收尾核对：本轮Duo已关闭，保留设备及数据；未遗留本任务构建、UI测试、录屏、安装或simctl diagnose进程。
