# 开发说明

[中文](CONTRIBUTING.md) · [English](docs/CONTRIBUTING_EN.md)

先阅读 README、docs/ARCHITECTURE.md 与 VALIDATION.md。使用自己的签名密钥，不将密钥或本机路径提交仓库。新增设备前核对屏幕尺寸、物理按键、API级别及内存限制。

## 修改与检查

1. 将需求写成状态、输入、预期状态与保存结果，分别处理一球、一局、一场比赛和运动会话。
2. 优先修改独立逻辑，再接页面与持久化。计分锁定与暂停、返回与撤销、局内检查点与整场FIT分别处理。
3. 运行 README 中4个Node检查器，再使用本机SDK执行原生测试、模拟器及真实设备检查。
4. 修改中文文字后，检查字符是否在 resources/fonts/cn16.fnt 中；需要时运行字体生成器。生成器需要 Pillow、fontTools 和 Noto Sans CJK Bold，字体许可必须保留。
5. 使用线条和几何图元画场地与结果效果，不在每帧创建字库、全屏缓冲或帧图片列表；在目标设备测量真实峰值。

## 可选设计工具

`node tools/check_serve_ui.cjs --preview` 输出绘图指令；`python3 tools/render_preview.py` 使用 Pillow 与系统 Noto CJK 字体重建文档预览；`python3 tools/build_guide.py` 从中文Markdown生成离线HTML。这些是文档工具，不是原生Garmin渲染器。正常构建不依赖Python。

## 提交问题

附设备型号、固件、SDK/扩展版本、最短复现步骤、预期行为及完整非敏感报错。不要附签名密钥、令牌、个人FIT或含私人信息的完整日志。一般问题可直接提交Issue。

## 发布

更新VERSION、公开说明和验证结果；运行 `python3 tools/package_release.py` 生成源码包、离线指南与校验文件。发布前检查ZIP无私钥、SDK、编译产物或个人路径。以一个当前版本展示功能和说明；发布备注应描述交付物、验证范围与使用方式。
