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
