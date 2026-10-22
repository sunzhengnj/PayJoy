# 2026-10-22：平衡 Duo 两栏，减少左页滚动

用户指出工资日历左页过长、右页大量留白。本轮实际重排工资日历、我的、薪资／工作时间设置和工资报告，并修正分享预览的宽高约束。未改业务数据格式、权限或保存入口。

环境：Xcode 27.1（27A9275），Debug 1.6（11），Duo iOS 27.1（24A94425），设备 `A199B0FE-1420-4D85-A191-5E91A9C10FCF`。一次仅运行一个低优先级构建／测试任务；模拟器顺序切换，未超过两台。相关源码哈希在 `source-sha256.json`。

## 实际实现及画面

| 页面 | 展开／书本布局 | 已执行 |
| --- | --- | --- |
| 工资日历 | 左侧标题、月份、日历；右侧当日详情、本月收入及月概览 | `calendar-five-rows-book.png`／`calendar-six-rows-book.png`：2026年10月五行、8月六行日历连同图例完整可见，无需下滑。`calendar-book-current.png` 为后续安装修订的实际页面。选中15日，展开竖向再折回仍为15日，见 `calendar-selected-portrait.png`、`calendar-selected-book.png` |
| 我的 | 左侧账户、实时活动和会员；右侧设置入口 | `profile-book.png`：三组设置均可见。进入工作时间设置，临时选择星期六后展开旋转再折回，页面与选择保留；`profile-navigation-draft-portrait.png` 为草稿证据，`settings-before-book.png` 是设置重排前的空白问题 |
| 工作时间 | 左侧上下班／计薪日；右侧午休／计算预览／保存 | `worktime-book.png`：主要内容完整显示；保存按钮在右侧分区内。验证中曾发现外层620pt限宽把按钮移向折痕，已改为按当前分区限制宽度并重建、实拍 |
| 薪资设置 | 左侧类型／金额／计薪天数；右侧发薪日／计算预览／保存 | `salary-book.png`：不用下滑即可查看主要设置。`salary-draft-book.png`、`salary-draft-portrait.png`：未保存12345及光标往返保留。返回不保存再进入，恢复10000。硬件输入用于本次连续性，不以输入自动化中不确定的标点事件证明地区小数规则；D13仍待专项验证 |
| 工资报告 | 左侧主题报告／进度；右侧分享入口／趋势／年度数据 | `report-book.png`：两栏内容均完整可见，分享入口无需在左侧继续下滑。此组使用已有 Debug `pro-report-energy` 夹具，仅证明展示，不证明真实会员购买和薪资记录 |
| 分享海报 | 限宽后按3:4计算预览高度 | `share-preview-before-portrait.png` 显示旧约束顺序造成顶部大块空白；`share-preview-portrait.png` 修正后完整预览可见。`share-preview-book.png`：弹层留在左侧完整分区，底部分享可达，短分区内海报仍允许滚动；未触发对外分享 |

窄屏阅读顺序保持原有逻辑。阅读页使用 ArrangementView 外置双滚动容器；设置表单采用同一个 ScrollView 和 AnyLayout 重排同一输入树，避免更换输入控件。全屏展开竖向与窄屏恢复限宽单列。没有通过横向放大所有卡片填满空间。

## 验证范围

- `tests.log`／`test-summary.json`：日历与我的初次重排后，136项iOS XCTest通过。
- `final-tests.log`／`final-test-summary.json`：完成设置、工资报告重排后，136项通过，0失败、0跳过；结果包 `/Volumes/CodexOffload/Builds/PayJoyBalancedFinal.xcresult`。
- 最后的分享预览只调整两个视图修饰符的顺序，后续 `share-preview-build.log` 构建通过，再取得上述 Duo 竖向／书本实拍；没有把此前测试伪称为该末次改动之后重新运行。
- 编译使用 `nice -n 20`、`-jobs 1`、`OTHER_SWIFT_FLAGS=$(inherited) -DPAYJOY_DUO_SDK -j1`，保留原SDK条件。
- 报告最初批量采集时5秒等待仍停留启动页：`report-fixture/pro-report-energy.png` 是未就绪诊断图，**不作为页面通过证据**。后续等待实际页面就绪后人工审阅，`report-fixture/report-final-inner.png` 才是重排完成后的内屏截图。脚本复用已启动设备，结束清除了状态栏覆盖。

普通 iPhone 补测：先关闭 Duo，再启动既有 Review iPhone（iOS26.5，1170×2532），安装相同末次 Debug 构建。`iphone-salary.png`、`iphone-profile.png`、`iphone-worktime.png`、`iphone-share.png` 已逐张查看，保留单列及保存／分享按钮，海报比例正确。此组使用已有 Debug 夹具，只覆盖版面，不代表普通手机完整计时、导航、隐私流程或 iOS17运行通过。海报底部品牌出现重复“开薪”，另列为后续文案修订，不混入布局结论。

本组以简中、经典主题验证布局。五语言、四主题、全部键盘／弹层、滚动组合、iOS17运行、真实海报导出仍未全部覆盖；不代表全 goal 完成。全局剩余项目见 `../../POST_RESTART_ACCEPTANCE.md`，真实计时见相邻 `2026-10-22-live-continuity/` 和 `2026-10-22-offwork-flow/`。
