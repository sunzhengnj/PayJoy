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

## 2026-10-23 后台执行状态

- 英语（美国）、日语、韩语的旧商品名称已按表改为 ClockJoy 名称，并单独提交内购审核；刷新确认三项本地化状态均为“正在等待审核”。旧的已批准名称在新文案获批前仍保留。
- 简体中文、繁体中文的正式商品名称原本为 `开薪 PRO`、`開薪 PRO`，本轮保留原值；上表中文会员名称仅是备用填写建议，未另行发起中文更名审核。
- 已建立 `2.0.0` 版本草稿。五种语言的描述、支持网址、营销网址和隐私政策网址均已修改，并在刷新后台后重新读取验证。隐私政策编辑框明确说明“所有更改将随 App 的下一版本发布”。
- 在售版本仍为 `1.5`；本轮未上传或发布 App 二进制。公开商店仍可能显示旧网址，旧网址当前提供兼容跳转。
- 发布范围待用户选择：基于在售 1.5 做最小整改版，或随完整 2.0.0 发布。草稿版本号和元数据可随该选择调整。
- 内购价格、Product ID、销售地区和用户权益保持不变。
