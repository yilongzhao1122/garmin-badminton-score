# Connect IQ 发布与手机设置

[English](CONNECT_IQ_EN.md) · [使用说明](USER_GUIDE_CN.md)

## 1. 手机调整与应用更新

| 操作 | 开发者需要做什么 | 用户需要做什么 |
| --- | --- | --- |
| 修改已经开放的设置，如菜单字号 | 提前在程序内定义支持的选项 | 手机设置 → 保存 → 等待手表同步 |
| 新增功能、修复错误、加入未附带的字体或布局 | 修改源码、编译并向同一商店条目提交新版IQ | 在手机Connect IQ中更新并同步 |
| 开发阶段测试 | 本地构建PRG | 用USB侧载到手表 |

手机同步的是参数值，例如MenuFontSize=19；手表执行已经安装的代码。它不是远程修改MC源码，也不能凭一个数字生成没有附带的新字体。商店更新则下载开发者发布的新程序，不需要每位用户自己编程或接数据线。项目中的GitHub Release是源码发行，与Garmin商店上架分别处理。

本项目是watch-app，商店类别应为设备应用，而不是Watch Face表盘。安装包扩展名是`.prg`，商店上传包是`.iq`，不是`.npr`。

## 2. 当前手机设置实现

| 文件 | 职责 |
| --- | --- |
| resources/settings/properties.xml | 定义MenuFontSize，默认19 |
| resources/settings/settings.xml | 定义手机列表选项19/16 |
| resources/strings/settings.xml | 英文设置标题与选项 |
| resources-zhs/strings/settings.xml | 简体中文设置标题与选项 |
| source/BadmintonApp.mc | 启动读取Properties；onSettingsChanged重读并刷新 |
| source/ChineseFonts.mc | 在已缓存的16px/19px字体间切换 |

当前手机开放菜单字号，默认为19像素，另可选紧凑16像素。标题、条目、计数和提示均使用选定字号，过长文字最多两行。比赛比分、场图和A1/A2/B1/B2保持现有字体。手机改字号不会重置比分、清理存档、保存/放弃或暂停运动。

其他比赛选项可以在手表菜单设置。若今后开放到手机，应先规定新比赛默认值与进行中比赛的边界，不能在同步时直接改掉当前比分或局制。

## 3. 本地测试设置

1. 使用新版完整工程，运行Monkey C: Verify Installation。
2. Ctrl+F5 → fenix6xpro，长按2检查默认19px菜单。
3. 在CIQ Simulator中使用File → Edit Persistent Storage → Edit Application.Properties data（名称以本机SDK界面为准），把MenuFontSize改为16或19并保存。
4. 应用运行中验证菜单刷新，停止再启动验证偏好读取；测试比分和运动会话不变。
5. 若SDK提供Trigger App Settings事件，可用于检查回调，但只发事件不会替你定义或修改配置。
6. 运行原生测试、检查中文边界、长按/短按和峰值内存，再真机验收。

本项目已执行适配源码/模拟API检查；未在发行整理环境执行原生SDK编译、真实手机设置传输、真实堆内存或Garmin商店审核。默认大号字库增加了资源开销，不能把PNG文件KB当成实际堆用量。

## 4. 在自己的电脑导出IQ

1. 下载完整v0.10.0工程，用VS Code打开根目录。
2. 沿用自己的Developer Key，保存在工程外并备份；不要发送私钥或上传GitHub。
3. 核对manifest.xml：类型watch-app、目标fenix6xpro、应用ID保持不变。目前只声明该目标，不把未测试的其他设备加入支持列表。
4. 完成SDK编译、Run No Evil、模拟器以及Fēnix6X Pro/Solar真机测试。检查计分、局末、保存/放弃、心率、中文、字号与内存。
5. Ctrl+Shift+P → **Monkey C: Export Project**。
6. 按向导选择导出位置、自己的开发密钥以及支持的设备/语言，生成`.iq`。如向导要求填写版本，使用与本次发行对应的0.10.0。
7. 保留编译日志。导出出错先解决，不把PRG或源码ZIP改扩展名伪装成IQ。

## 5. 上传至Garmin商店

1. 打开 [Garmin官方Submit an App](https://developer.garmin.com/connect-iq/submit-an-app/)，登录发布用的Garmin账号，通过Submit an App入口进入上传后台。
2. 阅读并由账号所有者接受后台要求的开发者协议，补齐发布者资料。
3. 新建应用条目，上传刚导出的IQ，等待二进制检查。
4. 按后台要求填写应用名称、设备应用类别、版本说明、中英文介绍、支持联系方式/链接以及数据处理信息。支持链接可使用本项目GitHub Issues；请确认它是你愿意公开使用的联系方式。
5. 上传后台要求的商店图标和真实运行截图。项目docs/assets是电脑重建示意图，不能标为原生模拟器或真机截图。商店图片规格以当前后台为准。
6. 在开发者预览/测试流程中用自己的账号安装，实测手机设置页面、16/19px切换、活动保存及Connect同步。官方说明允许上传后在审核前由开发者自行预览和下载测试。
7. 测试完成后提交审核；等待通过后才向所有用户公开。GitHub发布成功不代表Garmin审核通过。

本仓库提供源码、字号设置定义及发布说明，没有生成或代替你上传已签名IQ；签名密钥位于你自己的电脑。商店是否接受、页面字段和审核结果以Garmin后台为准。

## 6. 从手机修改字号

以商店安装的对应版本为前提，保持手机和手表连接：

1. 打开Connect IQ Store手机应用。
2. 进入设备（Device/My Device），选择对应手表。
3. 打开我的设备应用（My Device Apps），选择羽毛球计分。
4. 设置（Settings）→ 菜单字号 → 大号19像素或紧凑16像素。
5. 保存（Save），等待传输和同步完成，再查看手表菜单。

应用正在运行时通过onSettingsChanged刷新；未运行时下次启动读取。同步不保证瞬时完成。手机只有通过商店安装且包含设置定义的版本才会提供相应设置页；仅将PRG复制到GARMIN/APPS不会自动在手机注册它。

## 7. 后续程序更新

开发者修改代码后重新导出IQ，在**同一个商店应用条目**中发布新版本。保持应用标识和自己的签名密钥一致，完成升级与存档兼容测试。用户在Connect IQ Store → 我的设备 → 更新 → 全部更新，也可随标准同步获取可用更新。更新应用的代码仍由开发者编译，用户侧不需要编程。

## 官方资料

- [上传与审核流程](https://developer.garmin.com/connect-iq/submit-an-app/)
- [Properties与Storage](https://developer.garmin.com/connect-iq/core-topics/persisting-data/)
- [onSettingsChanged API](https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/AppBase.html#onSettingsChanged-instance_function)
- [手机设置操作](https://support.garmin.com/en-US/?faq=TMj0wxIdjh382mBFh5rG46)
- [Connect IQ内容更新](https://support.garmin.com/en-IN/?faq=apVl8M95hQ4WG7wzgKgeA8)
