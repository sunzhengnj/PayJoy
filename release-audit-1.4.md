# 开薪 1.4 发布前全局审计

## 审计范围

- 设备与视口：iPhone 17 Pro，402 × 874 points，3× 截图。
- 主要流程：首页、统计与工资日历、愿望、个人中心与设置、帮助与法律链接、PRO 会员页、首次引导。
- 语言：简体中文、繁体中文、English、日本語、한국어；首次引导额外检查英文长文案。
- 主题：经典、粉色、好运喵、午夜。
- 无障碍：常规字号与 Accessibility XXXL；Reduce Motion 降级逻辑。

## 用户流程健康度

1. 首页与主导航 — 健康
   - 移除重复且臃肿的愿望进度区，保留用户自主填写的愿望进度。
   - 老板键和新愿望保留熟悉的功能图标与本地化辅助标签。
2. 统计、工资日历与工资报告 — 健康
   - 修复英文动态文案泄漏中文与 “in Monthly” 语法问题。
   - 修复午夜主题工资报告入口的浅底白字对比度。
3. 愿望与显影未来 — 健康
   - 手动进度是主入口；显影未来成为更丰富的原创图像叙事，不发随机进度、不替用户控制目标。
4. 个人中心、工作时间与帮助 — 健康
   - 关于页显示动态版本 `v1.4`；主要编辑按钮和法律链接达到 44-point 点击区域。
   - 工作时间和计薪天数在辅助字号下自动重排，英文帮助标题不截断。
5. PRO 会员页 — 健康
   - 首屏聚焦一次买断、价格和核心权益；愿望预演移至权益列表底部并明显压缩。
   - 章节预览交互仍保留，不再用长段落重复罗列权益。
6. 首次使用引导 — 健康
   - 新增原创“时间变成收入与自由”插画及轻微浮动动画；Reduce Motion 下静态显示。
   - 精简为单页设置：默认使用小开，不再让用户在首次使用时选择搭子；中文、英文与最大辅助字号均无关键内容截断。
7. 隐私、法律与上架配置 — 工程侧健康
   - App 与 Widget 都包含 `PrivacyInfo.xcprivacy`。
   - 隐私政策、服务条款、支持与删除账号页面的五种语言地址均已在线返回 HTTP 200。

## 本轮关键修复

- 版本统一为 `1.4 (7)`，覆盖 App、测试目标和 Widget 的 Debug/Release 配置。
- 新增原创引导资产：`PayJoy/Assets.xcassets/onboarding_time_to_income_v1.imageset`。
- 首次引导支持本地化品牌名、动态两列选择布局和 Reduce Motion。
- 会员页愿望预演从首屏移到底部，改成紧凑横向卡片。
- 修复英文剩余工作日文案匹配和自然语序。
- 关于页、点击区域、辅助字号、午夜主题对比度完成发布前收口。

## 验证结果

- 自动化测试：61 passed，0 failed，0 skipped。
- Debug simulator build：通过。
- Release generic iOS device archive：通过（为本地结构验证，`CODE_SIGNING_ALLOWED=NO`）。
- Archive：`/tmp/PayJoy-1.4-ready-no-companion-20260810.xcarchive`。
- Archive 内容：App `1.4 (7)`、Widget `1.4 (7)`、arm64、两个 Privacy Manifest 均存在。
- Bundle IDs：`app.payjoy.kaixin` / `app.payjoy.kaixin.widgets`。
- `git diff --check`：通过。
- 详细视觉 QA：`/Volumes/CodexOffload/Projects/project/PayJoy/design-qa.md`，最终结果 `passed`。

## 上传前仍需人工确认

1. 在 App Store Connect 锁定唯一正式非消耗型 Product ID；工程当前兼容 `payjoy.pro.lifetime` 与 `app.payjoy.kaixin.pro.lifetime`，不能在不知道线上既有商品的情况下擅自删除其中一个。
2. 使用 Apple Distribution 证书和正式 provisioning profiles 重新归档并上传；本地归档未签名，不能直接提交。
3. 将 `iCloud.com.sunzheng.PayJoy` 的 CloudKit schema 部署到 Production。
4. TestFlight 真机验证购买、恢复购买、iCloud 同步、Widget/App Group、通知、老板键、首次引导动画与 VoiceOver 顺序。
5. 上架元数据最终确认海外名称 `Workday Joy`、`退勤まで`、`퇴근까지` 的品牌审批状态。

## 结论

本地工程、视觉与自动化测试已达到 1.4 发布候选状态。完成上述 App Store Connect、签名、CloudKit 与 TestFlight 外部检查后即可提交审核。
