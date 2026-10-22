# App Store 精选提名草稿（待审阅，未提交）

依据 Apple 的 [提名流程](https://developer.apple.com/help/app-store-connect/manage-featuring-nominations/nominate-your-app-for-featuring/)准备。提名类型：**App Enhancements**。关联应用：开薪 / ClockJoy（内部项目名 PayJoy；App Store ID 6771261514，提交前在 App Store Connect 核对）。平台：iPhone；相关国家/地区、语言和预期发布日期以实际发布计划为准。

Apple 的 [精选说明](https://developer.apple.com/app-store/getting-featured/)要求至少提前两周告知计划；[提名操作指南](https://developer.apple.com/help/app-store-connect/manage-featuring-nominations/nominate-your-app-for-featuring/)建议至少提前三周。以 2026-10-22 计算，内部候选目标 11 月 6 日相隔 15 天，满足两周提前量，但短于三周建议期；若在 10 月 22 日提交，11 月 12 日才满 21 天。对外发布日期应在完整验收后选定，可在表单中使用日期范围，不能把内部目标或提名等同于审核通过和获选。

## 提名名称

开薪：专注到下班，展开今天的 Duo 新体验

## 详细描述（中文版）

开薪把工资进度、下班倒计时和收工仪式放在同一条工作日脉络里。新增专注可选 25、45 分钟或自定时长，并在开始前显示预计结束时间；临近下班时可一键「专注到下班」。进行中只显示一个醒目的剩余时间，可在适用时切换查看距下班时间；暂停、恢复、提前结束和到点结果都保留真实时长。专注不额外计薪，也不自动更新愿望目标。

针对 iPhone Duo，展开后的首页把「今天到了哪里」与「现在可以做什么」分成两页；半折叠摆在桌上时，界面转为纯白或纯黑的桌面钟，上半屏远看时间，下半屏操作。折叠与展开只改变呈现，不中断专注、加班或当天进度。原有的漫画主题、统计、工资日历、愿望和收工回执仍组成完整的日常体验。

我们希望让用户在一天中少翻页、少被数字打断：看清进度，完成眼前这一段，再主动收下今天。这是一次围绕真实工作节奏和折叠形态设计的重大体验更新，而非独立的通用番茄钟。

## Detailed description (English alternative)

ClockJoy brings earnings progress, the countdown to the end of work, and a deliberate end-of-day moment into one flow. The new Focus experience offers 25-minute, 45-minute, and custom sessions with an estimated finish time before starting. Near the end of a workday, Focus Until Off Work makes the final stretch one tap away. During a session, one large timer stays in view; people can pause, resume, end early, and see the actual time they focused. Focus time never adds earnings or changes wish progress automatically.

On iPhone Duo, opening the phone places today's progress beside the actions available now. In tabletop posture, a black or white desk clock keeps one readable time above the hinge and the controls below it. Folding changes the presentation while the same session continues. The four comic themes remain on the home screen; the running Focus view stays deliberately minimal and keeps salary amounts out of sight.

The result is a workday that takes fewer page changes: see where today stands, finish one stretch, then choose when to close the day. Duo layout and continuity claims must be checked against the final build and real device evidence before this text is submitted.

## Helpful Details（提交前按验证结果更新）

- 特色演示：17:42 展开看今日进度 → 摆成桌面钟 →「专注到下班」→ 折叠中持续计时 → 到点看真实时长 → 用户主动打开收工回执。
- 拍摄依据：[产品页预览与 Duo 辅助演示分镜](FEATURED_PREVIEW_STORYBOARD.md)；产品页预览只用应用内画面，Duo 实体形态展示另供提名辅助链接审阅。
- 专注作为独立亮点展示：普通 iPhone 可从专注标签选 25、45 分钟或自定时长；计时页不显示工资金额，暂停后重启应用仍能恢复同一段时间。
- 视觉：首页延续四套漫画主题；计时与桌面钟使用无金额、单一时间、纯白/纯黑界面。
- 本地化：准备验证五种语言的专注、Duo 双页与桌面钟文案；只陈述实际通过的项目。
- 隐私：专注页不展示工资金额；原有金额隐藏设置继续作用于收入相关页面。
- 辅助链接（最多五项）：候选构建 TestFlight、Duo 形态演示、专注完整流程演示、设计故事与支持页面。链接与权限待候选构建完成后填入。

## 卖点与放行证据

以下是提交前的逐句核对表。`qa/` 中的旧 Debug 图片只能帮助发现布局问题；不能替代同一最终候选构建的截图或连续录像。素材目录与拍摄顺序见[精选候选画面](../../marketing/app-store/featured-candidate/README.md)及[预览分镜](FEATURED_PREVIEW_STORYBOARD.md)。

| 提名中的主张 | 当前证据 | 提交前仍需取得 |
| --- | --- | --- |
| 25／45 分钟、自定与预计结束时间；暂停、恢复和真实结果 | 已运行完整iOS XCTest，最新137项通过；[真实2分钟专注](../testing/evidence/2026-10-22-live-continuity/README.md)完成暂停、进程重启、继续和自然到点，单条记录。后续暂停标签保留时间含义，五语言回归先失败后通过 | 最终构建的普通 iPhone 完整操作录像，核对到点与提前结束各只生成一条记录 |
| 「专注到下班」接到用户主动收工 | [真实21:58→22:05流程](../testing/evidence/2026-10-22-offwork-flow/README.md)已有连续原片和数据核验：固定截止、暂停扣除、实际06:02、一次结算，主动点击后才创建一张回执；空愿望存储未改 | 最终冻结构建复拍相同流程，并补已有非零愿望进度和其他工作日／午休场景；重开内屏瞬时黑画面仍在区分系统与应用路径 |
| Duo 展开今日双页、半折叠桌面钟与折叠期间会话连续 | Duo已实际运行当前Debug；[日历、我的、设置、报告重排](../testing/evidence/2026-10-22-balanced-columns/README.md)有实拍，六行日历无需下滑，日期和薪资草稿跨形态保留；已有真实会话开合连续性录像。全部窗口／弹层仍未覆盖 | 同一候选构建的展开／桌面／书本／合上截图及不间断形态切换录像，检查折痕、相机区和侧栏 |
| 纯白／纯黑单时间界面与金额隐私 | 当前运行／桌面钟与结果实拍不含工资金额；分享预览默认隐藏具体金额已实拍。后台遮罩、锁屏及全部系统弹层仍未完成设备验收 | 两种外观、锁屏、后台快照、分享及密码弹层的最终构建画面；确认个人数据未进入营销素材 |
| 原有主题、统计、日历、愿望及回执仍可用 | Duo双列和iOS26.5普通iPhone单列已有当前修订QA，分享海报竖向大块空白已修复；四主题／五语言的全页矩阵仍未完成 | 四主题、目标市场语言、设置滚动底部、会员权限及 iOS 17 回归；按用户决定不设无障碍专项门槛 |
| 国际品牌在产品页与购买页一致 | [美国区公开页面](https://apps.apple.com/us/app/clockjoy-workday-countdown/id6771261514)的标题为 ClockJoy，但描述仍出现 PayJoy，内购显示名仍为 “PayJoy PRO”；[英文替换稿](en-US.md)已准备 | 在 App Store Connect 核对并更新英文描述与内购显示名；保留内部 bundle ID、产品 ID 等技术标识，复查公开页生效后的文字与购买界面 |
| 可供编辑团队直接查看的演示与产品页素材 | 提名和拍摄脚本已成稿；`raw/` 尚无放行图片，辅助链接未建立 | 按 Apple 规格导出最终截图／预览，核对 App Store Connect 实际展示；填写可访问的辅助链接并由用户审阅 |

用户已授权本机最多同时启动两台模拟器，并撤销高CPU自动取消规则；当前已在同一台Duo完成应用运行、真实计时和多页交互。按单任务低优先级构建、顺序切换测试机执行，不把个人手机作为常规测试设备。当前QA证明的是其注明的修订和覆盖范围，不能直接放行最终候选素材。

2026-10-22重新核对Apple官方指南：[提名指南](https://developer.apple.com/help/app-store-connect/manage-featuring-nominations/nominate-your-app-for-featuring/)仍建议至少提前三周，支持最多五个辅助URL。单项可保存草稿；CSV导入会自动提交，因此本项目仅准备可审阅本地材料，不生成待直接上传的CSV。

较早修订曾通过[免签名Release离线核验](../testing/evidence/2026-10-22-release-current/README.md)：主应用与组件版本为1.6(11)，Duo新API保留弱引用，部署目标仍为iOS17。该Release产物早于当日下午的页面修订；晚间恢复后当前源码另已通过[Debug arm64模拟器测试编译](../testing/evidence/2026-10-22-post-recovery/README.md)。这些产物未分发签名或归档，不能当作TestFlight构建链接，也不能替代上述设备与素材放行项。

## 提交前必填核对

- [ ] 确认 App Store Connect 中的应用名称、App ID、帐号角色与实际可选市场。
- [ ] 确认发布日期或日期范围；11 月 6 日目前只是内部候选版本目标。
- [ ] 按实际提交日重新计算提前量；若在 10 月 22 日提交，三周建议期对应 11 月 12 日或更晚，不把建议期写成硬性资格规则。
- [ ] 将描述与最终已实现功能逐句对照，删除未验收或未交付的承诺。
- [ ] 核对英文 App Store 描述及内购显示名已统一为 ClockJoy，并在公开页与购买界面复查；内部产品 ID 不因展示名称改变。
- [ ] 补充来自最终构建的截图/视频与可访问的辅助链接；iPhone Dynamic Island 中尺寸截图至少一张，6.9 英寸与 Duo 素材另行审查。按用户要求，本版不以无障碍专项结果作为提名材料。
- [ ] 经用户审阅后，在 App Store Connect 保存/提交提名。
