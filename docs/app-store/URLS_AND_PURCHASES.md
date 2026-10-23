# 公开网址与内购名称填写表

更新日期：2026-10-23。此表是可填写稿，不代表 App Store Connect 已保存或已审核通过。

## 网址

| 字段 | 中文 | 英文 |
| --- | --- | --- |
| Marketing URL | `https://sunzhengnj.github.io/ClockJoy/` | `https://sunzhengnj.github.io/ClockJoy/en/` |
| Support URL | `https://sunzhengnj.github.io/ClockJoy/support.html?lang=zh-Hans` | `https://sunzhengnj.github.io/ClockJoy/support.html?lang=en` |
| Privacy Policy URL | `https://sunzhengnj.github.io/ClockJoy/privacy.html?lang=zh-Hans` | `https://sunzhengnj.github.io/ClockJoy/privacy.html?lang=en` |

其他语言使用相应首页路径和 `lang=zh-Hant`、`lang=ja`、`lang=ko`。正文、推广文本、自定义产品页和其他已配置语言也要逐一核对旧公开名称与网址。

## 非消耗型内购本地化

保留现有 Product ID `payjoy.pro.lifetime`，修改用户可见的 Display Name 和 Description。Reference Name 只是后台追踪名称，可以改为 `ClockJoy Lifetime Membership`，不能以改它代替修改本地化。

| 语言 | Display Name | Description |
| --- | --- | --- |
| 简体中文 | 开薪会员 | 一次购买，解锁会员功能。 |
| 繁体中文（台湾／香港） | 開薪會員 | 一次購買，解鎖會員功能。 |
| 英语 | ClockJoy Membership | One-time unlock for membership features. |
| 日语 | ClockJoy メンバーシップ | 1回の購入でメンバーシップ機能を利用できます。 |
| 韩语 | ClockJoy 멤버십 | 한 번 구매로 멤버십 기능을 이용하세요. |

核对全部已配置语言，尤其是英文回退文案。Display Name 不超过 30 个字符，Description 不超过 45 个字符。已批准商品的本地化变更需要审核；批准前商店仍显示原文案。

## 上线后证据

- 保存后台各语言名称、网址字段和审核状态截图，记录时间。
- 在正式商店环境核对商品显示名称和系统购买确认页；本地 `.storekit` 或模拟器付款页不能作为正式商品整改完成证据。
- 检查中国与美国商店公开网站链接；缓存尚未更新时记录为待复核。
- 分地区销售数据单独保存，不能提交到公开仓库。
- 代码提交、新站部署、后台保存、审核通过和正式付款页复核分别记录。

参考：[Apple 内购信息](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information)。
