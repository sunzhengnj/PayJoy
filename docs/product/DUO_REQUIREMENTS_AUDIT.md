# Duo、专注及全应用动效逐项核对

核对日期：2026-10-23。对应用户原始「摆下是桌面钟，展开是今日双页」方案和后续专注／全应用打磨要求。无障碍专项按用户后续指示不作为本版门槛；已有适配不删除。

“源码已覆盖”只表示找到了实际实现并完成离线审查，不等于真机／模拟器验收通过。离线审查范围见 [离线证据](../testing/evidence/2026-10-22-offline-polish/README.md)；后续已取得真实2分钟专注和专注到下班连续原片，见[计时恢复](../testing/evidence/2026-10-22-live-continuity/README.md)、[到下班及回执](../testing/evidence/2026-10-22-offwork-flow/README.md)。设备项目统一在 [重启后验收清单](../testing/POST_RESTART_ACCEPTANCE.md)，不再以旧截图证明当前候选版。

## 原始核心体验

| 条目 | 实际实现与本轮结论 | 仍需设备确认 |
|---|---|---|
| 仅首页根页有效上下分区自动进桌面钟 | `AppRootView.showDesk` 同时检查标签、根可见、首页弹层、初始化、专注／回执／发薪展示、抑制状态及布局；Home 回报 `canAutoShowDesk`。源码已覆盖 | D01、D03；尤其原生导航回调次序 |
| 展开／合上恢复首页，不打断编辑和弹层 | 原首页 NavigationStack 保留在桌面钟背后；首页表单／弹层阻止自动进入。普通业务编辑页本轮统一稳定输入子树 | D01、D03、D07、D12–D15 |
| 工作中／午休显示距下班 | `DeskClockMode.select` → `clockTitle/clockValue`；午休有独立标签，不显示工资 | D06 |
| 上班前／下班后／休息日显示下次上班，无时间则休息中 | `AppState.nextWorkStartDate` 复用 `SalaryCalculator.nextScheduledWorkStart`；nil → `.resting`。既有下一工作日测试覆盖周末及日期覆盖记录 | D06 |
| 专注中单一时间，可切换已有时间含义 | 两种展示共用 root 的 `focusShowsOffWorkTime` Binding；运行／桌面均读取同一 active session。10月23日真实运行中切换两种时间，同一会话、无暂停字段、截止不变；原生UI再次确认切换不暂停，并将实测19.333pt高的菜单入口扩大至至少44pt。暂停标签另以五语言夹具审阅 | D05、V01；全主题、书本及更多姿态仍待测 |
| 加班显示本次时长；结束沿用确认及回执 | Desk 调用 root `stoppingDeskOvertime` → `OvertimeStopSheet` → 停止后再开回执；不直接结算绕过确认 | D06 |
| 纯黑／纯白、等宽数字、沿用外观 | Focus／Desk 共用 `focusData.prefersDarkBackground`；纯色背景和 monospacedDigit，无薪资金额。本轮短淡变及按压反馈 | V01 |
| 时间、标签、按钮不跨折痕 | Desk 上下视区按实际 reserved division；时钟字号与入口共用空间预算。本轮单列回退改用完整分区，并补相机避让 | D02、D14、D16 |
| 主动退出本次折叠不重入，展开后恢复资格 | scene 的 `deskSuppressedForCurrentFold`；仅 UIHinge fullyOpen 回调清除，尺寸变化不清除 | D03 |
| 屏幕常亮默认关、仅活跃可见时生效 | root owns idle timer；AppStorage 默认 false。10月23日LLDB已读取关闭偏好、专注、首页／书本、桌面钟、后台、返回和结果的实际值，符合当前可见性条件；偏好已关回false | D09、D10；隐私密码、锁屏、其他标签及弹层尚未覆盖 |
| 17:42→专注到下班→结果→主动收下今天 | `focusToOffWorkDuration`、`startFocus`、`finishFocus`、`dismissFocusResult` 与 cover dismissal 后回执串联。未自动领取 | D04；完整演示仍待录制 |
| 左页收入／进度／当前状态／下班总结 | `HomeView.expandedHome` 左栏唯一 EarningsCard，沿用 snapshot 和主题 | D07、V01 |
| 右页专注／加班收工／回执／愿望手动更新入口 | expandedFocusActions、回执、加班、聚焦愿望跳转、摸鱼与提前收工；右栏不重复收入主卡 | D07 |
| 两页实时数据一致、独立滚动 | 同一 AppState；各自 ScrollView＋AdaptiveScrollPosition。横折不再误选水平双列 | D07、D14 |
| 折叠前后滚动连续、书本避折、窄宽回退 | 四个主页面共用滚动锚点策略；本轮愿望标题加入稳定锚点，摸鱼完成结果移到 Home 状态层 | D07、D15 |
| 四漫画主题；专注纯色；愿望手动、不折算新增收入 | AppTheme 继续用于首页／准备页；Focus 和 Wish 更新链独立，无新增薪资或愿望写入路径 | V01、D04、D06 |

## 架构、页面及状态

| 条目 | 实际实现与本轮结论 | 仍需设备确认 |
|---|---|---|
| Duo 系统 TabView、普通 iPhone 漫画底栏、复用 AppTab | AppRootView 用 hasDuoHinge latch 选择导航壳；保留原普通手机壳 | I01、D01；首次识别时机仍需看启动过程 |
| 系统铰链识别，同 scene 开合不反复换壳 | WindowSceneReader 使用 UIHingeInteraction；可用性一旦为 true 不因闭合／离开层级置回 false。SDK 头文件说明 handler 接收初始状态 | D01；冷启动展开／合上／桌面三种姿态 |
| 尺寸、安全区、分区、遮挡统一布局上下文 | AdaptiveLayoutContext 从每个页面自己的 GeometryProxy 读取；不按设备型号或屏幕分辨率分支，不重复减 Geometry 已排除的安全区 | D02、D14 |
| ArrangementView 与 reservedRegions，滚动容器外布局 | 双列使用 ArrangementView 包裹两个 ScrollView；Desk 按 reservedRegions 直接分配上下视区，滚动只在操作区。参见下方实现取舍 | D02、D16 |
| 每列至少 320pt，边距与书本实际分区纳入判断 | `hasRoomForTwoColumns` 已有边界测试；本轮明确横向折痕时回退单个完整分区 | D02、D14 |
| AppState／FocusSession 唯一计时来源，尺寸不创建会话 | Focus／Desk 只读投影；折叠处理只改展示状态。摸鱼额外 Timeline 已移除，复用 AppState.now | D04、D05、D17 |
| 展示、抑制、滚动、编辑草稿留在 scene／页面 | root 和各页 State；本轮 Focus／薪资编辑仅保留一个输入树；首页摸鱼结果、统计成就展示不再存于单双列可替换卡片 | D07、D12、D13、D15 |
| Duo 不强制竖屏、隐藏手动旋转；普通手机沿用 | FocusOrientationPolicy 按当前 UIWindowScene 的 session 标识更新；Duo allButUpsideDown，手动按钮仅普通手机 | I01、D01 |
| 统计工资概览／报告 vs 日历／记录双列 | StatsView.overviewCards/detailCards；本轮收拢成就弹层到稳定页面层 | D07、D15 |
| 日历与选中日期详情并排，选中日期保持 | SalaryCalendarView 双列；selectedDate、editingDay 均在页面 State；编辑器本轮接单分区 | D07、D15 |
| 愿望聚焦与其他并排，编辑和收藏页可用 | WishExperienceView；本轮标题／添加按钮移入左页或单列，三个编辑 sheet 与收藏列表接分区 | D07、D15 |
| 设置／引导／会员限宽可滚动 | Profile 改为左侧账户／会员、右侧设置入口；SalarySettings 在书本与宽屏重排主表单／预览操作，保留同一输入树，竖向限宽620pt。ProfileDetail、Onboarding、ProPaywall 仍限宽滚动；全矩阵待测 | D08、D14–D16 |
| 弹层、输入、分享预览及隐私遮罩避让 | 本轮接入加班、实际薪资、愿望编辑、成就、回执、分享预览、老板键等；系统 Photos／Mail／Activity 控制器交由系统布局，仍需逐个实测 | D08、D10、D14、D16 |
| 不新增公开 API／迁移、不变薪资愿望回执记录格式 | 本轮仅内部 View／布局属性和展示 State；业务 Codable 字段及存储入口未改 | 当前差异审查；设备保存重开见 D13、D15 |
| 无新增收费门槛 | Duo 布局、Desk、Focus 无会员判断；原有会员动作沿用原门槛 | V01 |

## 动效源码核对

| 路径 | 当前行为 | 离线结论 |
|---|---|---|
| 专注准备→运行→结果→再来一段 | 0.22秒淡变；只绑定业务阶段。折叠仅改变几何，不给运行→桌面添加布局插值 | 避免旧计时界面在跨折痕移动过程中穿过遮挡；视觉待 V01 |
| 预设／自定义时长 | 0.24秒选择与输入展开；保留同一输入树，原始草稿不被格式转换回写。原生输入已验证三种全角／混合输入开始25／45分钟，四种无效输入禁用开始；全角45分钟草稿在实际书本／桌面／外屏往返后仍能从原光标继续输入 | D12、D15；其他输入×姿态及软件键盘／输入法完整矩阵待补 |
| 运行／暂停／继续 | 同一主时间，新增已暂停标签；按钮文字淡变、轻按反馈；结果动作保持44pt以上 | 不新增循环呼吸或闪烁；可读性待 V01 |
| 每秒数字、黑白外观 | 倒计时数字向下、加班数字向上；0.18秒外观过渡 | 不更改计时取值与结算；实机观感待 V01 |
| 首页↔桌面钟 | 0.2秒透明度过渡，保留首页内容与滚动状态 | 折叠及相机实时变化待 D01、D16 |
| 标签／导航／sheet | Duo 系统负责，普通手机保留现有漫画栏弹簧；不叠加全屏横向飞入动画 | 导航位置及系统工具栏待 D01、I01 |
| 首页装饰／金额、统计装饰 | ambient 可见性、scene 活跃性、原有减少动效偏好共同控制；被 Desk／Focus／隐私／业务弹层覆盖时停止；进度条改为短 easeOut | 不以源码检查代替 CPU／帧率测量；见 D17 |
| 浮动与闪光组件 | ComicIdleBob 消失／禁用时取消并归零，再出现重启；Twinkle schedule 真正暂停 | 后台、切标签、反复开合无重复循环需 D17 |
| 发薪／愿望完成／回执 | 保留既有单次入场和选择反馈；发薪延迟会员提示改为随页面取消的 Task；回执详情与确认按钮放入可达分区 | 入场不会新建业务记录；中途关闭、返回待 V01 |
| 老板键与其他窄高页面 | 计算器键盘可滚动，退出引导保留；提前收工确认卡可滚动 | 触控、键盘、横屏短分区待 D14 |

## 实现取舍与验收边界

- 专注准备与薪资输入保留同一输入树，使用 AnyLayout 在书本／宽屏重排左右内容，横向折痕仍回退较大完整分区。表单共用一个滚动容器，优先保留草稿和输入身份；日历、我的、报告等阅读页继续使用 ArrangementView 外置双滚动容器。
- 普通业务页遇横向折痕时，使用较大的完整分区；书本式保留左侧单列或双页。不会为增加双屏内容而让控件跨折痕。代价是小分区留空、需要滚动。
- 桌面钟继续直接使用系统 reservedRegions 给出的分区矩形，而非再嵌套 ArrangementView。双页才使用 ArrangementView。这是对原方案容器选择的保留实现差异：上方字号预算和下方最小可操作高度可直接核对，需 D16 确认坐标真实一致。
- 当前已取得新版启动页、专注分区、真实计时和重排页面的新截图；没有提交、发布、申请精选或完成分发签名归档。旧 Release 证据已不是本轮全部源码的 Release 证据；最终归档应在设备验收与候选版冻结后重建。
- 本核对表关闭了已确认的离线实现缺口；运行验收失败仍可能要求再改代码。完整 iOS XCTest、五语言四主题画面、折叠录像、性能与最低系统运行都未由离线测试替代。

## 10月22日晚补充：减少左侧滚动

用户要求右侧空余时重新组织内容，而非把长页挤在左侧。已重排工资日历、我的、工作时间／薪资设置和工资报告；具体构建、图片与未覆盖项见[分栏证据](../testing/evidence/2026-10-22-balanced-columns/README.md)。完整 goal 仍进行中，不能用这组修订替代所有主题、语言、键盘和系统版本验收。

## 10月23日补充：专注显示与可见性

最新2.0.0(11)完整139项iOS XCTest通过。新增真实会话证明“距下班”可以与专注同时运行；三次暂停开合余量保持、自然完成及结果重启均只一条记录。实际常亮值与五语言标签画面、测试夹具修订分别记录在[本轮证据](../testing/evidence/2026-10-23-duo-focus-review/README.md)。未复现必须旋转才能恢复的持续黑屏，但原固定下班截止路径、性能与完整兼容矩阵仍未关闭。

输入连续性新增[原生形态与持久化证据](../testing/evidence/2026-10-23-pose-input/README.md)：专注／薪资草稿在内外屏及两种半折叠姿态保留原文和光标；正常模式全角薪资经过开合、保存、进程重启后数值正确并恢复原设置。该组7项UI同轮成功、受影响专项重跑成功，不能写成一次8/8；完整软件输入法、多语言／主题与剩余页面仍需逐项实测。
