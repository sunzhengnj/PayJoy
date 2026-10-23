# Duo 实际形态、输入焦点与正常模式持久化

基线ec7bb5c，2.0.0(11)，Xcode27.1（27A9275），Duo iOS27.1（24A94425）。本轮继续原输入验收计划Task2，完整Goal仍未全部验收。

## 验证设计

通过独立PayJoyPoseUITests scheme启用需要宿主配合的三项测试；普通PayJoyUITests scheme跳过这些测试，防止无人操作时等待或改动正常设置。脚本只连接当前已核实的Device Hub PID；每次Open／Partially Open／Rotate Right／Closed均要求AX成功、保留Device Hub实拍，再写入对应请求的确认。宿主与测试代码均只在QA工具／测试目标，不进入应用发布目标。

焦点检测使用app.typeText输入7再删除，期间不重新点击字段；既校验原文，也校验追加位置。先前首轮让每个形态直接接续下一形态，全程不重新点字段。后续加强版本在每次形态的焦点检测之后检查开始／保存操作能否在当前分区内滚动到、通过原生命中检测，并满足44pt点击区域；检查完明确回到输入框，再开始下一次形态变化。软件键盘和所有输入法全矩阵不由这组硬件／原生事件输入测试替代。

正常模式不设PAYJOY_SCREENSHOT_MODE，用原生界面先保存不同的基准24123.89／20.5，进程退出再进入确认基准；再分别输入日文、德文全角金额和天数，实际半折叠→旋转→展开后保存，再次退出并重开，应读到12345.67／21.75。最后通过界面恢复原值，并再重开核对。保留正常测试前后的独立业务快照。使用截图模式保存回读不能替代本项。

## 已复现的点击区域问题

专注时间菜单原生点击高度19.333pt，新断言先失败，见menu-red-summary.json及本地menu-red-tests.log。为菜单标签添加最小44×44pt布局和矩形contentShape；不修改计时来源或切换语义。首次加强后的原生专项通过，菜单切到距下班再切回后仍保持运行。

## 中间证据的限制

首轮/Volumes/CodexOffload/Builds/PayJoyPoseInputFirst20261023.xcresult四项通过，但持久化测试发现原值本来就是12345.67／21.75，因此不能证明新写入。该轮两组真实开合草稿／光标证据有效；持久化以不同基准的后续运行判断。不能只看四项绿色就放行。

最初NSRunningApplication按bundleIdentifier查询返回了pid=-1的旧登记，工具已改用当前进程清单中的Device Hub PID；缺按钮或AX操作失败均直接报错，不默认为成功。

首次组合保存运行在德文清空字段前置条件失败；原生Command-A／方向键在测试中没有移动选择范围，typeText也不能把forwardDelete特殊字符当作向前删除。原生编辑菜单完成过一次恢复，但空字段仅有占位文字、展开后的菜单未出现等情况仍使整轮失败。对应失败摘要保留，均不能计为应用保存缺陷或通过。

辅助方法只用于已有薪资文本：触摸拖动到末尾，先输入7并断言确实追加在原文末尾，再删除原长度加1，断言清空后才输入目标。新建专注输入框本来为空，直接输入，不将占位文字当作旧值。日文／德文金额及计薪天数专项先通过（caret-drag-summary.json）。

随后完整8项运行为7通过、1失败、0跳过，见accepted-first-summary.json；不能称整轮8/8通过。正常模式失败被光标断言拦住：短框20.5输入7后成为20.75，尚未清空和输入目标；其他七例及两组真实开合草稿／光标检测均通过。触摸终点仍在字段内部，后续只将终点延至框右侧24pt，并恢复临时设置、单独复跑受影响的正常模式保存组合；对应源码哈希见combined-fixed-source-files.json。该专项重跑已通过（combined-fixed-summary.json，1通过／0失败／0跳过，317.668秒），两地区均完成不同基准、实际三次形态切换、保存冷重开和原值恢复；原始失败没有改写成通过。

139项iOS XCTest在PayJoyPoseInputUnitRetry20261023.xcresult通过，0失败／0跳过。此前PayJoyPoseInputUnit20261023.xcresult在测试宿主建立连接前超时，并未进入139个用例；失败摘要与本机进程采样保留。重试通过不证明该偶发启动问题的根因已解决。应用源码的FocusView／SalarySettingsView哈希与139项验证时一致，后续修订只涉及测试与QA工具。

界面实际审阅包含accepted/pose-03-Rotate-Right、pose-05-Closed（专注草稿／外屏），pose-09-Partially-Open、pose-10-Rotate-Right（薪资桌面／书本）及两组action原生截图。正在编辑时滚动位置会使标题离开视口；本项核对草稿和主操作可达，不声称所有内容都无需滚动。系统键盘在宿主实拍可见；XCUIScreen原生画面需配合宿主画面判断内外屏及系统键盘，不能只取main或只看宽高比。

## 证据边界

本组不放行软件键盘／输入法完整矩阵、所有输入×所有姿态、五语言四主题、普通iPhone、iOS17、物理设备实时活动及其余页面导航／弹层。Save在组合结束的展开姿态实际点击；不能由命中检查推断所有半折叠姿态都已保存成功。仍能见到Invalid frame dimension警告，根因未关闭。

正常业务快照只比较实际存在的salary.settings、focus.data.v1、engagement.state.v1三项，不声称覆盖所有数据。SalarySettings.workdays的类型是Set<Int>，编码数组顺序会变；保存原始快照，只在比较该字段时按成员排序，其他数组保留顺序。

独立复核及未放行范围见[review.md](review.md)。原始xcresult位于/Volumes/CodexOffload/Builds，截图和日志留在本证据目录；Git保存摘要、源码哈希、形态确认与截图索引。verify-results.py要求这些本地截图存在，不适用于仅有Git文本的副本。

## 重跑方法

只开一台已就绪的Duo，先核实运行中的构建和Device Hub PID；按AGENTS.md的单任务、低优先级及实际Swift单线程要求完成PayJoyPoseUITests build-for-testing。将scripts/qa/duo_pose_control.swift编译为本地工具，再运行：

```sh
python3 scripts/qa/run_duo_pose_tests.py --output /absolute/evidence/folder \
  --control /tmp/payjoy-duo-pose-control --device-hub-pid VERIFIED_PID -- \
  nice -n 20 xcodebuild -project PayJoy.xcodeproj -scheme PayJoyPoseUITests \
  -configuration Debug -destination 'platform=iOS Simulator,id=VERIFIED_DUO_ID' \
  -derivedDataPath /absolute/derived-data -jobs 1 -parallel-testing-enabled NO \
  -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO \
  -resultBundlePath /absolute/new-result.xcresult test-without-building
```

输出目录必须不存在，防止混入上一次确认记录。只在专用测试机上运行；正常模式测试会通过界面修改并恢复薪资设置。如失败或中断，先用PAYJOY_ORIGINAL_SALARY日志和运行前快照核对／恢复测试机，再继续。无需读取剪贴板，不操作用户手机。

## 本轮收尾

verify-results.py已通过：7项UI同轮成功＋受影响正常模式专项成功、139项iOS XCTest、13条本轮形态确认及7条专项确认、三项业务快照恢复、202张本地截图校验。另保留此前13条形态确认及中间失败。模拟器已关闭，未删除设备或数据；未归档、上传或发布。当前正常模式德文基准与回读原生画面已审阅，原生截图可能带旋转方向，需与Device Hub实拍合看，不单凭截图方向判断设备显示。
