# 羽毛球计分 / Garmin Badminton Score v0.11.0

## 中文

- 统一开局及直接加分入口，首局和次局计时与运动记录一致。
- 比分、计时、检查点和历史合并保存；结算失败保留比分，防止FIT已存后继续漏记。
- 修正记录失败菜单、准备局撤销接发球计时和旧实时心率。
- 新增暂停／继续比赛（含纯计分）、跨页防连按及比分页接发球提示。
- 自由练习／胜方先发、完整规则面板、局中间歇和第三局换边提示。
- 最近8场比赛历史，整场结果与局数优先，保留日期和逐局详情。
- 19/16px手机菜单设置、原按键及A1/A2/B1/B2编号、轻量场地和结果动画保留。

## English

- Unified START/direct scoring initializes game timing and requested recording.
- One snapshot stores scores, timing, checkpoints and history; pending settlement prevents unrecorded continuation after a saved FIT.
- Fixed failure-menu actions, READY service-undo timing and stale live heart rate.
- Added score-only pause/resume, shared cross-view input guards and service hints.
- Free-play/winner-first options, rule panel, interval and deciding-game change reminders.
- Eight-match history with match result first, dates and per-game detail.
- Existing 19/16px phone setting, controls, player IDs and lightweight graphics retained.

## 下载 / Downloads

| 文件 / File | 用途 / Purpose |
| --- | --- |
| garmin-badminton-score-v0.11.0-source.zip | 完整工程及双语文档 / Complete source and bilingual documentation |
| garmin-badminton-score-v0.11.0-guide-cn.html | 离线中文指南 / Offline Chinese guide |
| garmin-badminton-score-v0.11.0-guide-en.html | 离线英文指南 / Offline English guide |
| SHA256SUMS.txt | 校验 / Checksums |

196项逻辑/模拟检查通过。官方SDK 9.3.0 Debug、Release及测试程序编译通过，使用SDK内置信息生成的设备描述；正式设备包、模拟器及真机验收未执行。仍为源码发行，不附带测试PRG或签名密钥，也不代表Connect IQ已上架。

196 logic/mocked-API checks pass. SDK 9.3.0 debug, release and test-program compiler checks pass with generated device metadata. Official device-package, simulator and watch testing remain outstanding. Source release only; no test PRG or signing key included, and no Connect IQ store publication implied.

See docs/REVIEW_CHANGES_CN.md / docs/REVIEW_CHANGES_EN.md for the review decisions, and VALIDATION.md for evidence and scope. Code MIT; font subset SIL OFL 1.1.
