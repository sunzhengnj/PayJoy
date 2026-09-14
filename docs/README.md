# 开薪 / ClockJoy 产品站与法律页面

这个目录用于 GitHub Pages 托管。`index.html` 是产品落地页（SEO / GEO 用），法律页仍是 `privacy.html`、`terms.html`、`support.html`。

产品首页：

```text
https://sunzhengnj.github.io/PayJoy/
https://sunzhengnj.github.io/PayJoy/en/
https://sunzhengnj.github.io/PayJoy/zh-hant/
https://sunzhengnj.github.io/PayJoy/ja/
https://sunzhengnj.github.io/PayJoy/ko/
```

指南（给搜索引擎和问答模型引用）：

```text
https://sunzhengnj.github.io/PayJoy/guides/countdown.html
https://sunzhengnj.github.io/PayJoy/guides/vs-calculator.html
https://sunzhengnj.github.io/PayJoy/guides/lock-screen.html
```

App Store 文案审计与可粘贴稿在 [`app-store/`](app-store/AUDIT.md)。

---

# 法律与支持页面

法律页仍是根目录的 `privacy.html`、`terms.html`、`support.html`、`delete-account.html`、`legal.html`。它们会根据 `?lang=` 或浏览器语言切换文案。`zh-hans/` 等语言目录里的法律页继续重定向到这些根文件；各语言目录的 `index.html` 则是对应语言的产品首页。

## 页面

- `index.html`：法律与支持入口
- `privacy.html`：隐私政策
- `terms.html`：服务条款
- `support.html`：支持与反馈
- `delete-account.html`：账号删除说明

## GitHub Pages 发布方式

1. 将项目推送到 GitHub。
2. 打开仓库 `Settings` -> `Pages`。
3. `Build and deployment` 选择 `Deploy from a branch`。
4. Branch 选择 `main`，目录选择 `/docs`。
5. 保存后，GitHub 会生成类似下面的地址：

```text
https://<github-username>.github.io/<repository-name>/
```

当前计划仓库为 `sunzhengnj/PayJoy`，页面地址为：

```text
https://sunzhengnj.github.io/PayJoy/privacy.html
https://sunzhengnj.github.io/PayJoy/terms.html
https://sunzhengnj.github.io/PayJoy/support.html
https://sunzhengnj.github.io/PayJoy/delete-account.html
```

固定语言路径示例：

```text
https://sunzhengnj.github.io/PayJoy/en/privacy.html
https://sunzhengnj.github.io/PayJoy/ja/terms.html
https://sunzhengnj.github.io/PayJoy/ko/support.html
https://sunzhengnj.github.io/PayJoy/zh-hant/delete-account.html
https://sunzhengnj.github.io/PayJoy/zh-hans/index.html
```

正式上架前，需要把 App Store Connect 中的隐私政策 URL 指向实际的 `privacy.html` 地址。
