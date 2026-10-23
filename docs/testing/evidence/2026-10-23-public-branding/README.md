# 2026-10-23 公开名称与网站地址整改

## 已实施

- 产品站和法律／支持页面采用 `https://sunzhengnj.github.io/ClockJoy/`，在独立的 `sunzhengnj/ClockJoy` 仓库发布；源码仍保存在本工程 `docs/`。
- 清除产品站页脚的旧工程名称声明，更新各语言页面、canonical、Open Graph、站点地图、robots 和当前运营文案里的正式站点地址。
- App 内隐私政策、服务条款、支持及账号删除链接改用新站点地址。
- 旧站兼容入口由 `codex/legacy-site-redirects` 分支发布，保留原有路径并跳转到新站，保护已安装版本的法律与支持入口。已在浏览器复核 8 条代表路径，语言参数和页面锚点均保留，无脚本异常。
- 保留 Bundle ID、App Group、CloudKit、现有内购 Product ID、存储键和历史默认资料识别字符串，避免破坏升级、权益和用户数据。

## 已验证

- 静态检查：59 个 HTML 页面、604 个站内链接、26 个内嵌脚本，未发现缺失引用或脚本语法错误。
- 线上文件：72 个公开文件返回 HTTP 200，内容与导出文件一致。
- 真实浏览器：五种语言首页及法律／支持页，共 30 个组合正常显示；未发现旧品牌可见文案或页面脚本异常。
- 旧站兼容跳转：全部 59 个脚本通过语法解析，8 条代表路径通过线上浏览器复核，包括 `?lang=en` 和页面锚点保留。发布配置切换后曾仍提供旧构建，手动触发正确构建后复核；跳转脚本生成问题也已修正并复测。
- 修改过的 `ProfileView.swift` 通过 Swift 语法解析；App／Widget 的本地化显示名称和本地 StoreKit 商品显示名不含旧公开品牌。
- 本次未构建、安装或提交新的 App 二进制；以上不等于 App Store 在售版本已经更新。

## 待后台处理和正式环境复核

- App Store Connect：全部内购本地化的 Display Name／Description、Marketing URL、Support URL、Privacy Policy URL，以及其他公开商店文字。填写表见 `docs/app-store/URLS_AND_PURCHASES.md`。
- 本地 StoreKit 配置不是正式内购名称的验证依据；商品本地化审核通过后仍需核对正式系统购买确认页。
- App 更新需要独立提审；在售 1.5 与开发分支 2.0.0 的状态不能混同。
- 分地区销售报告、后台配置截图以及对外沟通记录保存在本地，不提交公开仓库。

## 本地证据索引

目录：`.audit/clockjoy-remediation-20261023/`。

- `before-live.json`：整改前站点和中美区公开商店字段。
- `static-validation.json`：静态链接和脚本检查。
- `browser-validation.json`：新站 30 个浏览器组合检查。
- `all-live-files.json`：线上静态文件逐一核对。
- `legacy-browser-validation.json`、`legacy-browser-validation.log`：旧站兼容跳转最终通过结果。
- `legacy-browser-before-rebuild.log`：切换构建前的失败输出。
- `en-home.png`、`en-privacy.png`：新站英文首页和隐私政策截图。
- `status.json`：当前状态及待办。

公开站点提交：`5170db5`；旧站跳转最终提交：`e5f8f20`（首次提交 `2761637` 后修正参数保留脚本）。仅发布网页与兼容入口，未改应用销售地区。

## 后台里程碑（2026-10-23）

已实际登录 App Store Connect，确认正式商品的英语、日语、韩语旧名称仍在使用。三项本地化更名已保存并单独提交审核，刷新核对均为“正在等待审核”；中文 `开薪 PRO`／`開薪 PRO` 保留。原已批准文案在新本地化获批前继续显示，不能据此标为正式购买页已整改完成。

已创建 `2.0.0` 草稿以解锁版本元数据。五种语言的描述、支持网址、营销网址和隐私政策网址均已保存，并通过刷新后重新选择语言读取验证。语言切换和保存存在异步延迟，首次复核未保留的繁体中文与韩文项目已重新保存，最终五种语言均通过。

本轮不修改价格、销售地区、技术标识、已购权益或隐私数据类型申报。公开商店仍在售 `1.5`，新网址字段随下一版本发布。发布范围待用户选择最小修正版或完整 `2.0.0`；没有上传、提交或发布新的 App 二进制，没有发送对外邮件。

新增本地证据：

- `asc-iap-before.png`、`asc-iap-waiting-review.png`、`asc-iap-waiting-review.json`：正式商品修改前后及待审核状态。
- `asc-iap-submission-confirmation.png`：Apple 确认提交 1 个内购项目。
- `asc-version-persisted-final.json`：刷新后五种语言版本元数据核对。
- `asc-privacy-reloaded-verification.json`、`asc-privacy-en-saved.png`：隐私政策网址刷新读取及随下一版本发布的提示。
- `backend-final-verification.json`：后台完整核查结果。
- `public-store-after-backend-edits.json`：中、美、日、韩、台、港公开商店仍在售 1.5 的状态；公开 App 名称已使用开薪／開薪／ClockJoy。

销售报表尚未访问，海外无付费成交目前仍依据用户说明。账号首页另提示账户持有人需查看更新后的付费应用协议；本轮未代用户接受协议，内购本地化提交已实际成功。
