# Duo 首页边界修复 · 2026-10-22

用户截图暴露两个运行时问题，本次直接修改布局并重新构建、安装到现有 Duo。

- 页头内图像高 147pt，外层原为 116pt 且默认居中，导致顶部按钮溢出。外层改为 147pt 并顶端对齐。
- 单区布局在安全区边界做硬裁剪，导致底部出现空白横条。现在仅当分区贴近屏幕底边时，将裁剪范围延伸至底部安全区；分区本身的布局尺寸和折痕边界保持原值。

## 已验证

`home-scroll-boundary-build.log` 为当前源码 Debug arm64 模拟器构建成功日志。`home-boundary-fixed-closed.png` 是当前安装版本的 Duo 外屏截图：顶部按钮完整、底部滚动内容延伸到屏幕边缘。`home-header-fixed.png` 是只修页头后的中间版本，不能当作最终版本截图。源码与可执行文件哈希见 `home-boundary-manifest.json`。

`inactive-outer-display-during-scroll-check.png` 是姿态改变后非活动外屏的黑图，不是滚动验收证据。当前只确认上述两个可见问题已修复，滚动到底、四种姿态、其他页面与普通 iPhone 回归仍待完成。

## 环境进展

此前获准的 120 秒启动观察中，应用已成功渲染，见 `two-minute-observation/`。用户随后撤销按高 CPU 自动取消的限制，已打开可见的 Device Hub 窗口，继续复用一台 Duo。当前不再把初始化期高 CPU 或旧 migration 标记单独视为应用无法运行的证据。
