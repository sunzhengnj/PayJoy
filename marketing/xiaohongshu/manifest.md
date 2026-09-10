# 开薪小红书视觉包

- 平台尺寸：1080 × 1440 px（3:4）
- 视觉方向：克制的编辑式版面；真实 App 截图为主体，保留原界面、角色插画和品牌色
- 主色：米白、暖黄、深蓝；避免炫富、促销和硬广感
- 产品截图：从当前工程的 iOS Simulator 截取
- 中文与版式：本地 AppKit 确定性渲染，保证界面和文字准确
- 发布成图：`01-cover-office-companion.png` 至 `04-after-work-relief.png`
- 原始产品截图：`app-screens/home.png`、`widgets.png`、`wish-tab.png`、`daily-report.png`
- 文案与发布说明：`COPY.md`
- 排版源文件：`render_product_cards.swift`
- 比例规则：完整截图保持原始宽高比；局部功能图只做等比例裁切，禁止拉伸
