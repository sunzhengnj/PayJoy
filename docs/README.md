# 开薪 / ClockJoy 产品站与法律页面

产品站源码保存在本目录；公开站点从独立仓库 `sunzhengnj/ClockJoy` 的 `main` 分支根目录发布。

## 正式地址

- 产品首页：<https://sunzhengnj.github.io/ClockJoy/>
- 英文首页：<https://sunzhengnj.github.io/ClockJoy/en/>
- 隐私政策：<https://sunzhengnj.github.io/ClockJoy/privacy.html>
- 服务条款：<https://sunzhengnj.github.io/ClockJoy/terms.html>
- 支持与反馈：<https://sunzhengnj.github.io/ClockJoy/support.html>
- 账号删除：<https://sunzhengnj.github.io/ClockJoy/delete-account.html>

首页支持 `en/`、`zh-hant/`、`ja/`、`ko/`。法律页根据 `?lang=` 或浏览器语言显示文案；例如 `en/privacy.html` 会转到 `privacy.html?lang=en`。指南位于 `guides/` 和 `en/guides/`。

## 发布

1. 在项目根目录运行 `python3 scripts/export_clockjoy_site.py`，导出到已被 Git 忽略的 `tmp/clockjoy-site/`。
2. 检查导出目录，再将其静态文件同步到 `sunzhengnj/ClockJoy` 的 `main` 分支根目录。
3. GitHub Pages 使用 `Deploy from a branch`，分支 `main`、目录 `/`；等待部署成功后检查线上各语言首页、法律页及资源请求。
4. App Store Connect 的 Marketing URL、Support URL、Privacy Policy URL，以及 App 内链接均使用本页列出的新地址。后台保存和审核状态需要单独验证。

导出器仅包含 HTML、JS、CSS、站点索引和 `assets/` 公开素材，不发布工程文档、测试证据、销售记录或邮件。不要直接把整个 `docs/` 目录复制到公开站点。

历史站点入口通过原工程仓库的 `codex/legacy-site-redirects` 分支根目录发布静态跳转页，兼容已安装版本。不要把其 Pages 发布源改回 `main/docs`，以免重新发布旧内容。过渡状态与正式地址更新分别记录，不能把新站部署成功当作 App Store 元数据已经更新。

App Store 文案及内购本地化填写表见 [`app-store/`](app-store/README.md)。
