# 开薪 / ClockJoy 上架交接清单

此清单只覆盖 Apple 开发者账号与 App Store Connect 中必须完成的配置；工程已按下列标识符实现。请先在 Apple 后台确认配置，再导出发行包。

## 已锁定的工程标识

| 项目 | 当前值 |
| --- | --- |
| 主 App Bundle ID | `app.payjoy.kaixin` |
| Widget Bundle ID | `app.payjoy.kaixin.widgets` |
| App Group | `group.app.payjoy.kaixin` |
| iCloud 容器 | `iCloud.com.sunzheng.PayJoy` |
| CloudKit 记录类型 | `PayJoyUserData` |
| CloudKit 字段 | `payloadJSON`（String）、`updatedAt`（Date/Time） |

`payloadJSON` 从本版本起使用带 `lzfse:` 前缀的压缩 JSON；应用仍可读取此前的 Base64 JSON，因此无需为已有用户执行数据迁移。

## 1. App Store Connect：一次性解锁

在 App Store Connect 中配置 Product ID 为 `payjoy.pro.lifetime` 的“非消耗型”内购产品，并完成名称、本地化、价格与销售地区设置。工程只使用该 ID 加载和购买新商品。

恢复购买时，工程仍识别历史兼容 ID `app.payjoy.kaixin.pro.lifetime`，避免旧测试或历史交易丢失权益；不要使用该兼容 ID 创建新的销售商品。提交付费内购前，还需在 App Store Connect 完成 Paid Apps Agreement、税务与收款信息。

本地调试使用 `PayJoy/Configuration/PayJoy.storekit`，其产品 ID 是 `payjoy.pro.lifetime`；这仅用于模拟环境，不能替代 App Store Connect 的正式产品。

## 2. CloudKit：部署生产 Schema

在 CloudKit Console 选择容器 `iCloud.com.sunzheng.PayJoy`，确认 Production 环境具有 `PayJoyUserData` 记录类型以及上表两个字段，然后部署 Schema。上架版本只能使用 Production Schema。

## 3. Certificates、Identifiers & Profiles

为主 App 的显式 App ID `app.payjoy.kaixin` 开启并核对：

- iCloud / CloudKit，关联 `iCloud.com.sunzheng.PayJoy`；
- App Groups，关联 `group.app.payjoy.kaixin`；
- In-App Purchase。

Widget 使用独立的显式 App ID `app.payjoy.kaixin.widgets`，并启用同一个 App Group。随后使用 Apple Distribution 证书创建与这两个 App ID 对应的 App Store provisioning profile，并在 Xcode 的 Release 配置中选用它们。

## 4. 上传前最终检查

1. 在 App Store Connect 创建与 `app.payjoy.kaixin` 相同 Bundle ID 的 App 记录。
2. 美区采用 [`docs/app-store/en-US.md`](docs/app-store/en-US.md) 中的 `ClockJoy` 名称、分类、关键词、英文描述与截图顺序，不再提交 `PayJoy` 作为公开名称。
3. 用 Release/Generic iOS Device archive，确认产物由 `Apple Distribution` 签名，而非 `Apple Development`。
4. 用 TestFlight 英文环境安装，确认主 App 与 Widget 均显示 `ClockJoy`，且商店页、截图、隐私政策、服务条款和支持页的英文品牌一致。
5. 验证首次启动引导、一次性解锁购买/恢复购买、iCloud 同步、Widget 读取 App Group 数据、隐私政策与服务条款链接。
6. 将系统日期分别设为发薪日前、发薪日和不存在对应日期的月底，验证彩蛋每天仅自动出现一次、首页入口全天可重复打开。
7. 用非会员点击“实际薪资”，确认点击前不显示会员角标，点击后才询问是否前往会员开通页；再用会员新增、修改、删除历史月份并核对月度、年度及工资报告。
8. 验证正常下班、提前收工、结束加班与跨午夜加班的收工回执；分享默认隐藏金额，主动开启才显示金额，全局金额隐私开启后不可显示金额。
9. 分别以简体中文、繁体中文、英语、日语、韩语及四套主题抽查首页、发薪日、实际薪资和收工回执；开启 VoiceOver、最大动态字体和减少动态效果检查关键流程。

## 官方参考

- [创建消耗型或非消耗型内购](https://developer.apple.com/help/app-store-connect/manage-in-app-purchases/create-consumable-or-non-consumable-in-app-purchases/)
- [配置内购概览](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases)
- [部署 CloudKit Schema](https://developer.apple.com/documentation/CloudKit/deploying-an-icloud-container-s-schema)
- [创建 App Store provisioning profile](https://developer.apple.com/help/account/provisioning-profiles/create-an-app-store-provisioning-profile/)
- [App Store Connect 工作流](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-workflow/)
