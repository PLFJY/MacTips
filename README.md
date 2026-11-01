# MacTips

[English](README.en.md) · macOS 26 及更新版本 · Swift 6 · 无第三方依赖

MacTips 是一个原生 macOS 菜单栏工具，在复制、粘贴、剪切和切换 Caps Lock 时显示轻量提示。提示窗使用系统 Liquid Glass，不抢焦点，也不会阻挡鼠标操作。

## 功能

| 功能 | 行为 |
| --- | --- |
| 复制与剪切 | 识别 `⌘C` 和 `⌘X`，在 800 毫秒内观察到剪贴板变化后显示提示 |
| 粘贴 | 按下 `⌘V` 时立即显示提示；不声称目标应用已成功粘贴 |
| 任意来源复制 | 推定右键菜单、应用内复制按钮等引起的剪贴板变化；可在设置中关闭 |
| 连续计数 | 同类操作连续发生时显示 `×N`，并刷新提示的停留时间 |
| Caps Lock | 显示大写锁定开启或关闭状态 |
| 外观与位置 | 调整停留时间、动画速度、六种预设位置或自定义位置，也可跟随鼠标所在屏幕 |
| 系统集成 | 菜单栏常驻、登录时启动、输入监控权限引导、中英文界面 |
| 辅助功能 | 跟随系统的降低透明度和减少动态效果设置 |

应用只检查剪贴板的变化计数和类型元数据，不读取、保存或上传剪贴板内容。键盘监听使用只读 Event Tap，不拦截原始按键。

## 构建与安装

### 环境要求

- macOS 26.0 或更新版本，支持 Apple Silicon 和 Intel。
- 完整版 Xcode 及其 macOS SDK；本项目已使用 Xcode 27 构建。
- 无需安装第三方 Swift Package 或运行时。

### 命令行构建

在项目根目录执行：

```sh
# 构建 Release 版本，产物写入项目的 build 目录
xcodebuild -project MacTips.xcodeproj \
  -scheme MacTips -configuration Release \
  -destination 'platform=macOS' -derivedDataPath build build

# 直接运行构建产物
open build/Build/Products/Release/MacTips.app
```

也可以用 Xcode 打开 `MacTips.xcodeproj`，选择 `MacTips` scheme，按 **⌘R** 构建并运行。

### 安装到当前用户的应用程序目录

先执行上面的 Release 构建，再运行：

```sh
mkdir -p "$HOME/Applications"
ditto build/Build/Products/Release/MacTips.app "$HOME/Applications/MacTips.app"
open "$HOME/Applications/MacTips.app"
```

安装命令会写入 `~/Applications/MacTips.app`。更新已有安装时，请先退出正在运行的 MacTips。项目默认使用 ad-hoc 签名；重新构建或移动应用后，系统可能要求重新授予权限。分发给其他用户需要自行配置合适的签名和公证。

### 首次授权

1. 点击菜单栏中的 MacTips 图标，打开 **设置 → 系统**。
2. 点击 **请求权限**，在 **系统设置 → 隐私与安全性 → 输入监控** 中启用 MacTips。
3. 若权限更改后未生效，退出并重新打开应用。
4. 在菜单栏的 **测试提示** 中预览浮窗。

未授权时，菜单栏和剪贴板变化检测仍可使用；全局快捷键和 Caps Lock 提示需要输入监控权限。

## 项目架构

```text
MacTips/
├── App/                       应用入口和生命周期协调
│   ├── MacTipsApp.swift    菜单栏应用与设置窗口入口
│   └── AppCoordinator.swift   连接监听器、权限状态与提示调度
├── Core/                      事件处理和系统服务
│   ├── KeyboardMonitor.swift  全局键盘事件监听
│   ├── ClipboardMonitor.swift 剪贴板变化轮询
│   ├── ClipboardEventCorrelator.swift  关联快捷键与剪贴板变化
│   ├── TipCoordinator.swift   提示显示与隐藏调度
│   ├── PlacementEngine.swift  屏幕位置与动画方向计算
│   ├── SettingsStore.swift    设置持久化
│   └── …                      权限、登录启动、快捷键分类与计数
├── UI/                        提示窗、菜单栏和设置界面
├── Resources/                 简体中文与英文资源
├── Tests/                     核心逻辑单元测试
└── MacTips.xcodeproj/      Xcode 项目与 scheme
```

事件流程：键盘监听器识别快捷键；复制和剪切由关联器等待剪贴板变化确认，粘贴直接进入提示调度。剪贴板轮询也可独立推定非快捷键复制；最终由同一个 OSD 窗口显示提示。

## 测试

```sh
xcodebuild -project MacTips.xcodeproj \
  -scheme MacTips -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath build test
```

自动化测试覆盖快捷键分类、剪贴板事件关联与合并、连续计数和位置计算。桌面验收仍应检查：Finder 文件复制与粘贴、TextEdit 和 Firefox 文本复制、Terminal 中的 `⌘C`、右键菜单与应用内复制、剪贴板管理器回写、Caps Lock、全屏和外接显示器、登录启动，以及撤销后重新授予输入监控权限。

## 使用限制

- macOS 没有公开 API 能仅凭剪贴板变化准确区分复制、剪切、清空和其他应用的回写。“任意来源复制”因此是推定，可能出现误报或漏报；短时间内的无关联回写会被合并。
- Finder 移动文件通常使用 `⌘C` 后接 `⌘⌥V`；Finder 的 `⌘X` 行为与文本编辑器不同。
- Num Lock、Scroll Lock 和 Insert 的通用状态提示尚未实现。

## 许可证与致谢

本项目使用 [MIT License](LICENSE)。功能行为参考了 WinTips；macOS 实现独立编写，未复用 FluentFlyout 的 GPL 代码或资源。
