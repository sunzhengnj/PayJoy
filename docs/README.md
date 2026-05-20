# 开薪 PayJoy 法律页面

这个目录用于 GitHub Pages 托管，当前仅提供中文页面。

## 页面

- `index.html`：法律与支持入口
- `privacy.html`：隐私政策
- `terms.html`：服务条款
- `support.html`：支持与反馈

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
```

正式上架前，需要把 App Store Connect 中的隐私政策 URL 指向实际的 `privacy.html` 地址。
