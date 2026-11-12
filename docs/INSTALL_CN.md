# 安装与构建

[中文](INSTALL_CN.md) · [English](INSTALL_EN.md)

本项目为 Connect IQ **手表应用**，目标 `fenix6xpro`，280×280像素。不是表盘，也不是手机应用。其他设备需适配和独立验收。

## 1. 准备环境

1. 安装 [Visual Studio Code](https://code.visualstudio.com/)。
2. 按照 [Garmin 官方开发入门](https://developer.garmin.com/connect-iq/connect-iq-basics/getting-started/)安装 Monkey C 扩展及当前要求的 Java 环境。
3. 安装 [Connect IQ SDK Manager](https://developer.garmin.com/connect-iq/sdk/)，下载 SDK 并设为当前版本。
4. 在 Manager 的 Devices 页下载 Fēnix 6X Pro / 6X Pro Solar 对应的 `fenix6xpro` 设备包。
5. VS Code 按 Ctrl+Shift+P → `Monkey C: Verify Installation`。通过后继续。

SDK版本与手表支持的API级别是不同概念。工程最低API为3.2.0；请用支持目标设备的工具链构建，不要仅为使用新SDK引入手表不支持的API。

## 2. 打开工程与密钥

1. 从 Releases 下载源码ZIP并完整解压，或克隆仓库。
2. VS Code → 文件 → 打开文件夹，选择直接包含 `manifest.xml`、`monkey.jungle`、`source`、`resources` 的目录。
3. 在 Monkey C 扩展的 Developer Key 设置中选用自己的密钥；首次使用可搜索扩展的生成开发密钥命令。
4. 把私钥保存到工程目录之外，并自行备份。不要上传仓库，不要放入Release，不要将他人的签名密钥用于构建。

双击 `.mc` 文件时选择 Visual Studio Code 只能编辑源代码；运行应用必须从工程发起构建。

## 3. 在模拟器操作

1. 打开 `source/BadmintonApp.mc`。
2. 按 Ctrl+F5，选择 fenix6xpro；等待编译成功并打开 CIQ Simulator。
3. 通过模拟器外框对应按键操作：2我方加分、3对方加分、4开球、5返回；长按2菜单。
4. 在命令面板运行 `Monkey C: Run Tests`。工程包含25个官方格式测试，实际结果以本机输出为准。

检查比分、单双打站位、菜单返回、锁定/解锁、局末否返回、整场保存/放弃、失败重试。模拟器的传感器与运动会话不能代替真实手表测试。

## 4. 构建并安装到手表

1. 停止模拟运行，选择 `Monkey C: Build for Device`，目标为 fenix6xpro。不要用 `_sim` 目标的模拟器构建替代真实设备构建。
2. 根据构建输出定位 PRG。工程默认输出位于 bin；以本机终端显示为准。
3. 使用数据USB线连接手表，先结束手表正在运行的活动。
4. 将 PRG 复制到手表 `GARMIN/APPS`，安全弹出并断开。后续覆盖更新请使用一致的应用ID、密钥和文件名。
5. 在手表活动列表中打开“羽毛球计分”；必要时通过活动列表“添加”查找。

源码发行不包含预编译PRG、IQ、SDK或私钥。中文点阵资源已附带，普通构建不需要Python。

## 5. 保存与手机同步

开启运动记录 → 按4开始 → 等待心率数据 → 结束比赛并选择保存 → 打开已配对的 Garmin Connect 并同步 → 在全部活动查看。

手机无需导入源码；应用通过USB安装在手表。默认使用普通FIT记录，可能归类为“其他”；详细比分与用时在表内应用查看，默认不上传自定义比分字段。选择“不保存”会丢弃当前尚未保存的运动记录，不会删除此前已经保存的活动。

## 6. 常见问题

| 现象 | 检查 |
| --- | --- |
| 找不到SDK或编译器 | SDK Manager设定当前SDK，确认扩展设置后重载VS Code |
| 没有可选设备 | 在Devices下载fenix6xpro，核对manifest目标 |
| 无法下载设备列表 | 检查网络、账号登录及SDK Manager状态；源码修改不能修复下载服务 |
| 心率显示 -- | 真机开启记录，佩戴手表并等待有效采样；检查设备心率功能 |
| 无法计分 | 检查是否锁定、是否在数据页、是否本局已结束；长按2仍可进入菜单 |
| 手机没有详细比分 | 当前默认只同步普通活动；表内比赛归档与Connect活动分别保存 |
| 构建或运行报错 | 复制完整错误、调用栈、设备ID与SDK版本提交Issue，不要附私钥 |

请参阅 [完整使用说明](USER_GUIDE_CN.md) 与 [验证范围](../VALIDATION.md)。
