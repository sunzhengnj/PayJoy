# Duo 桌面钟验收检查点（用户要求暂停）

2026-10-23，分支2.0.0，基线ef841a1，应用2.0.0(11)。本次保存进行中的源码与证据，不表示完成里程碑、完整Goal或发布验收。没有归档、上传或提交商店。

## 已取得的证据

- Duo iOS27.1：六项桌面钟测试6/6通过，31次实际形态操作；覆盖工作状态、进入／退出抑制、确认操作、跨午夜回执及黑白切换。加强后的“我的”根页阻挡与正常模式保存／冷重启另行2/2通过。键盘压缩时can=false，不能据此声称完整编辑阻挡矩阵通过。
- Duo完整单测141/141通过，0跳过。回执预览和保存共用开始工作日的金额投影；六月夹具18000/22=818.18，不增加加班工资算法。
- 两条截图偏好重启测试先失败后通过2/2；修正截图树的defaultAppStorage。该组及六项桌面钟运行的普通域16键未再变化，故意产生的两个RED偏好已恢复。
- 普通iPhone最后五项运行4通过、薪资输入1失败；时间含义切换保持专注运行、全角专注时长、两项偏好重置通过。后续薪资专项仍失败，不能计为全绿。
- 当前所有源码（含新增键盘高度断言）build-for-testing成功。新增断言尚未运行，未实施键盘产品修复。

## 暂停时仍未关闭

1. 普通iPhone薪资保存返回“我的”后保留键盘占位。已有失败专项与录屏；新增页面恢复高度断言只编译，下一次先执行RED，再决定是否在保存前结束编辑。SalarySettingsView.save未改。
2. 最终普通iPhone前后快照发现salary.settings与salary.day.records两个键变化，不能宣称全部截图存储隔离。关机后仅恢复这两个测试机键，14个PayJoy键与运行前逐项一致；隔离根因与相应RED/GREEN待查。原始前后快照保留本地，Git保存差异／恢复摘要。
3. iOS26.5本地StoreKit服务失败（140/141及专项失败）仍未查清；Duo27.1的141/141不证明普通手机购买或真实购买通过。显式SKTestSession实验已撤回。
4. 完整普通手机导航、相机／短分区／输入法与全部姿态、真实计时流逝及后台结算、语言主题、iOS17、物理设备组件／实时活动、动效性能及精选申请材料仍属于完整Goal。

## 溯源与续接

结果摘要保留所有先前失败／取消；成功摘要为desk-final-summary、preferences-green-summary、unit-final-summary和normal-final-summary。phone-final-first-summary与phone-viewport-failure-summary保留手机失败。原始xcresult在/Volumes/CodexOffload/Builds；媒体、原始业务快照与日志留本机。

review-fixed-source-files.json记录Duo成功运行对应源码；pause-source-files.json记录暂停工作树。应用源码一致；UI测试助手后来增加可见性处理及未执行的高度断言，不能把旧UI结果当成当前全部测试通过。

运行`python3 docs/testing/evidence/2026-10-23-desk-clock/verify-results.py --checkpoint`仅核对已记录证据和暂停源码，不批准里程碑。默认完整验收门禁仍要求尚不存在的成功薪资专项等证据，暂不满足。

测试机全部关闭，未删除设备或数据。Goal按用户要求暂停；收到继续指令后优先处理上述1、2项，再关闭本里程碑。
