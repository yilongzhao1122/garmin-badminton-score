# 发布到自己的GitHub

[中文](PUBLISH_CN.md) · [English](PUBLISH_EN.md)

本文件供项目维护者使用。发布目标为公开仓库 `yilongzhao1122/garmin-badminton-score`，不覆盖同名已有仓库。

## Windows发布脚本

1. 安装 [Git](https://git-scm.com/downloads) 与 [GitHub CLI](https://cli.github.com/)。
2. 在PowerShell运行下面的登录命令，按官方网页流程登录自己的账号。不要在聊天中发送密码或令牌。

```powershell
gh auth login --hostname github.com --git-protocol https --web --scopes repo,workflow
```

3. 完整解压源码ZIP，在工程根目录打开PowerShell，运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\PUBLISH.ps1
```

该参数只用于本次脚本进程，不修改系统执行策略。运行前可以先阅读PUBLISH.ps1。脚本核对账号、拒绝覆盖同名仓库，创建公开仓库并上传当前工程。需要发布工作流的权限由GitHub官方登录流程提供。

4. 在仓库Actions查看Logic checks与Source release。Source release仅在166项逻辑检查通过后生成源码ZIP、离线HTML与SHA256，并创建v0.10.0 Release。已有同名Release时不覆盖。工作流未获准或被禁用时，先在GitHub查看具体提示，再处理；不要把工作流启动误认为发布完成。
5. 检查Releases资产确实存在，再下载并校验SHA256。只有源码和指南，不包含预编译PRG。

脚本已做静态检查，当前环境没有可用的GitHub新建仓库认证，未实际运行发布脚本；不会承诺执行必定成功。若部分发布失败，保留现有仓库与本地工程，把非敏感错误交给维护者继续处理。

## 由Agent继续发布

也可以在自己的GitHub网页新建公开仓库，名称 `garmin-badminton-score`，启用“Add a README file”，并确保GitHub连接可访问它。将仓库URL交给Agent。初始化README可让连接使用已有分支上传工程；最终内容以本项目文件为准。

应用功能与手表安装见 [安装指南](INSTALL_CN.md)。GitHub源码发布与Connect IQ商店审核是不同流程。
