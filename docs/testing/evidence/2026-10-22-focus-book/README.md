# 专注准备页与结果页的书本分区

2026-10-22，Debug 1.6(11)，Duo iOS 27.1（24A94425）。

## 实现

- 书本姿态左侧选择时长、右侧开始与常亮设置；保持同一输入子树，展开后回到限宽单列。
- 结果页按折叠方向将时长与操作分到左右或上下区域，避开折痕。
- 桌面姿态的准备表单仍在完整单一区域滚动；没有宣称该页面已使用上下双区。
- 未修改 FocusSession、持久化格式或结算规则。

## 验证

`ios-tests.log` 与 `test-summary.json`：当前修订的 134 项 iOS XCTest 通过，0 失败。结果包：`/Volumes/CodexOffload/Builds/PayJoyFocusBook.xcresult`。

Device Hub 可见窗口中的交互实拍：

1. `setup-book-window.png`：准备页左右分区。
2. `custom-37-book-window.png`、`custom-37-tabletop-window.png`、`custom-37-open-portrait-window.png`、`custom-37-returned-book-window.png`：输入 37 后在书本、桌面、展开竖屏及返回书本时保留输入和光标。
3. `started-37-book-window.png`：按输入创建 37 分钟专注。
4. `end-confirmation-book-window.png`：结束确认可见。
5. `result-book-window.png`、`result-tabletop-window.png`：同一结果从左右切到上下，数字及操作分别留在分区内。

以上 UI 流程使用 featured-focus-tab 截图夹具，其时钟受夹具控制；这些截图只证明布局与输入连续性，不证明真实剩余时间、截止结算或持久化恢复。退出夹具后尝试正常模式验证，自动化点击未能推进引导，未取得真实计时恢复结果；原因尚未定位，不推断为业务故障。

D12、D15 只完成自定 37 分钟草稿与对应布局的部分验证。全角／无效输入、软键盘、多语言、其他编辑页、D04／D05 真实计时连续性、普通 iPhone 当前 Focus 修订仍待测。此前启动页实拍对应上一个布局修订，不作为当前 Focus 的普通 iPhone 回归证据。
