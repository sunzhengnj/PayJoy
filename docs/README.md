# 开薪 / ClockJoy 法律与支持页面

这个目录用于 GitHub Pages 托管。

- 根目录页面会根据 `?lang=` 参数或浏览器语言自动切换为简体中文、繁体中文、英文、日文或韩文。
- 同时也提供了固定语言路径页面，便于直接分享或在 App 内按语言跳转：
  - `zh-hans/`
  - `zh-hant/`
  - `en/`
  - `ja/`
  - `ko/`

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
