# 羽毛球计分 v0.10.0

中文在前，English below.

Garmin Fēnix 6X Pro / Solar 中文羽毛球运动应用，目标 `fenix6xpro`。

菜单默认19px，手机App Settings可选19/16px。标题、条目、计数和提示一起放大，过长文字保持字号并分两行。字号同步不改变比赛或运动会话。商店安装及审核流程见docs/CONNECT_IQ_CN.md；本源码发行不等于Garmin商店已上架。

- 单打/双打、21分制与15/11分练习制、单局赛或三局两胜。
- 2/3键计分，4键查看接发球场图及局末流程，5键返回/撤销，长按2打开中文循环菜单。
- 每局保存与下一局接发球设置；整场胜负效果；保存或放弃后回准备状态。
- 心率、热量、时长与时钟；普通FIT记录，详细比分和每局用时保存在表内。
- 线条场地、缓存16px标签和19px菜单字库、有界撤销与轻量结果效果。

## 下载文件

| 文件 | 用途 |
| --- | --- |
| garmin-badminton-score-v0.10.0-source.zip | 完整源码工程与文档 |
| garmin-badminton-score-v0.10.0-guide-cn.html | 图片内嵌的离线中文指南 |
| garmin-badminton-score-v0.10.0-guide-en.html | 图片内嵌的离线英文指南 |
| SHA256SUMS.txt | 下载校验值 |

本次为源码发行，未提供预编译PRG。使用自己的SDK与Developer Key构建，先模拟器验收，再Build for Device并通过USB安装至手表GARMIN/APPS。手机Garmin Connect用于已保存运动的同步，不直接安装源码。

## 验证范围

166项Node逻辑/模拟API检查通过；提供25个原生Run No Evil测试函数。发行整理环境未执行Garmin SDK编译、官方模拟器、真机峰值内存或真实FIT/Connect同步验收。默认自定义FIT字段关闭，Connect不提供详细比分图表。

代码MIT，字体子集SIL OFL1.1。完整使用说明、安装指南及验证报告见项目文档。

---

# Garmin Badminton Score v0.10.0

A Chinese-interface badminton watch app for Garmin Fēnix 6X Pro / Solar (`fenix6xpro`), with full Chinese and English project documentation.

Menus default to 19px; a phone App Settings list selects 19/16px. Titles, rows, counters and hints share the selected size; long text wraps without shrinking. Settings changes preserve the current match/activity. See docs/CONNECT_IQ_EN.md for store submission; this source release is not Garmin store approval.

- Singles/doubles, 21-point scoring and 15/11-point practice formats; one game or best of three.
- UP/DOWN scoring, START for service court and game-end flow, BACK for return/undo, hold UP for wrapping Chinese menus.
- Game checkpoints and next-game service setup; match-result effects; final save/discard returning to ready.
- Heart rate, calories, duration and clock; ordinary FIT recording, with detailed scores and game times kept locally.
- Primitive-based courts, cached 16px label and 19px menu fonts, bounded undo and lightweight result effects.

## Downloads

| File | Purpose |
| --- | --- |
| garmin-badminton-score-v0.10.0-source.zip | Complete source project and bilingual documentation |
| garmin-badminton-score-v0.10.0-guide-cn.html | Standalone Chinese guide with embedded images |
| garmin-badminton-score-v0.10.0-guide-en.html | Standalone English guide with embedded images |
| SHA256SUMS.txt | Download checksums |

This is a source release without a precompiled PRG. Build with your own SDK and Developer Key, validate in the simulator, then Build for Device and install over USB to GARMIN/APPS. Garmin Connect synchronizes saved watch activities; it does not install this source code.

## Validation

166 Node logic/mocked-API checks pass; 25 native Run No Evil test functions are supplied. Release preparation did not include Garmin SDK compilation, official simulator execution, device heap measurements or real FIT/Connect synchronization. Custom FIT fields are disabled by default; detailed score charts are not provided in Connect.

Code: MIT. Font subset: SIL OFL 1.1. See the project for Chinese/English overviews, installation, user guides and validation details.
