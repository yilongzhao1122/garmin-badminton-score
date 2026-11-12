# 代码结构

[中文](ARCHITECTURE.md) · [English](ARCHITECTURE_EN.md)

| 模块 | 职责 |
| --- | --- |
| ScoreEngine | 比分、局数、胜负、发球轮转、64步撤销与状态打包 |
| BadmintonApp | 应用生命周期、页面、比赛流程与持久化协调 |
| ScoreDelegate | 五键输入与计分防抖 |
| ScoreView / CourtUi / ServeUi | 比分布局、场地图、接发球提示 |
| MatchMenu | 中文层级选择器、循环导航、局末确认与轻量结果效果 |
| RecordingController | 运动会话启动、暂停、继续、保存、放弃与错误处理 |
| GarminRecordingBackend | 原生ActivityRecording与活动数据适配 |
| MatchReport / GameCheckpoints | 每局用时、整场汇总与固定最多3局检查点 |
| PerformanceStats / DataPagesUi | 心率、热量、时长与时钟 |
| ChineseFonts | 缓存单套16px点阵字库 |
| MatchFitFields | 可选自定义FIT字段实现，公开默认关闭 |

## 状态提交

计分引擎与运动会话分别维护。修改下一局时先收集发球方、发球人、接球人；完成确认后一次提交，避免返回键造成半完成状态。检查点每局最多一份，重复保存替换同局内容。下一局预设复用不可变撤销快照，避免复制整条历史。

保存成功后才清理当前状态；原生FIT已保存而归档尚未成功时，重试不再重复生成FIT。整场保存后保留最后一场归档，准备下一场。应用普通退出与用户明确结束比赛是不同事件。

## 资源与计时

`monkey.jungle` 仅将 resources 打包为运行资源。docs/assets 与 design 中的图不作为手表背景加载。中文使用 BadmintonCN 子集，保留字体许可；大比分使用设备数字字体，按实际宽高适配。

每局时间从正式开球到结束，排除局间准备与手动暂停；对局总时间包含局间休息、排除暂停；原生活动时长还可能包含完赛后的确认等待。数据未知时显示未知，不补造历史时间。
