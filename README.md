# WinTipsMac

WinTipsMac 是面向 macOS 26 及更新系统的原生菜单栏工具。它使用 SwiftUI、AppKit、Core Graphics Event Tap 和 `NSPasteboard.changeCount`，在屏幕上显示复制、粘贴、剪切和 Caps Lock 提示。应用不读取剪贴板载荷，也不保存或上传按键、文本、图片或文件内容。

## 构建与运行

1. 在 Xcode 27 或更新版本打开 `WinTipsMac.xcodeproj`。
2. 选择 `WinTipsMac` scheme，运行 macOS 应用。
3. 从菜单栏图标打开 Settings，允许 Input Monitoring，然后在系统设置中启用 WinTipsMac。权限更改后如未立即生效，请退出并重新打开应用。
4. 用菜单栏的 Test Tips 验证 OSD；测试提示不会写剪贴板，也不会伪造按键。

命令行构建与测试：

```sh
xcodebuild -list -project WinTipsMac.xcodeproj
xcodebuild -project WinTipsMac.xcodeproj -scheme WinTipsMac -configuration Debug -destination 'platform=macOS' build
xcodebuild -project WinTipsMac.xcodeproj -scheme WinTipsMac -configuration Release -destination 'platform=macOS' build
xcodebuild -project WinTipsMac.xcodeproj -scheme WinTipsMac -configuration Debug -destination 'platform=macOS' test
```

本项目无第三方 Swift Package。设置保存在当前用户的 `UserDefaults` 中。登录启动使用 `SMAppService.mainApp`。

## 功能和权限

- 使用 listen-only Event Tap 识别物理 Command+C/V/X；快捷键之外的 Command/Shift/Option/Control 组合会被排除，重复 keyDown 不提示。
- 粘贴提示表示检测到 Command+V 按键，不代表目标应用成功粘贴。
- 复制和剪切提示要等最多 800ms 的剪贴板 changeCount 更新确认；不读剪贴板内容。
- 任意来源复制是启发式推定：系统没有公开 API 能仅凭剪贴板变化区分复制、剪切、清空、密码管理器或剪贴板管理器的回写。应用只检查类型元数据；元数据不可用或为空时采取保守策略，不显示推定复制。
- 高频、无快捷键关联的剪贴板变化在 250ms 合并。独立的快捷键操作仍分别确认。
- OSD 使用 SwiftUI `.glassEffect` 和不激活、点击穿透的 AppKit `NSPanel`。系统启用降低透明度时使用不透明背景；减少动态效果时不执行滑动动效。
- 支持六种屏幕边缘预设、自定义可拖动位置、鼠标屏幕选择、显示时长和动画速度。
- 全局键盘监听需要 Input Monitoring 权限。没有该权限时菜单栏和剪贴板轮询仍工作，但键盘快捷键与 Caps Lock 不可检测。应用不会要求 Accessibility、Full Disk Access 或 Screen Recording。
- 登录启动在未签名的本地调试运行中可能受系统策略限制；如系统注册失败，设置界面会显示错误。

Num Lock、Scroll Lock 和 Insert 未实现：macOS 没有适用于所有键盘的通用状态 API，因此应用不伪造这些状态。

## 真实 Mac 手动验收

请在启用 Input Monitoring 后逐项检查。自动化测试覆盖快捷键分类、剪贴板关联/超时/合并和计数模型，但不能替代这些桌面验证。

- [ ] Finder：复制文件，再粘贴到另一个文件夹；检查 Copy/Cut/Paste 提示。
- [ ] Finder：验证其剪切文件实际交互限制（通常通过 Command+C 后 Command+Option+V 移动）；不要把 Command+X 提示当成 Finder 一定支持。
- [ ] TextEdit：复制选中文字、粘贴；空选区 Command+C 不应显示已复制。
- [ ] Firefox：网页选中文字复制、地址栏粘贴；也试试右键菜单复制。
- [ ] Terminal：Command+C 中断前台程序时不应误报复制；在可复制文本的上下文中检查实际行为。
- [ ] 使用应用内复制按钮，检查任意来源推定提示。
- [ ] 连续执行多次真实复制，检查 `×N`；用剪贴板管理器时检查连续回写是否被合并。
- [ ] 切换 Caps Lock，检查开启和关闭文案；检查键盘设置中重新映射 Caps Lock 的情况。
- [ ] 在全屏应用、多个显示器和位于主屏幕左侧/上方的显示器上验证 OSD；拔除显示器后验证回退。
- [ ] 启用、关闭登录启动；撤销再授予 Input Monitoring 后检查监听恢复。
- [ ] 开启系统降低透明度、减少动态效果设置，检查可读性和动效回退。

## 架构

- `App/`：SwiftUI 菜单栏入口及生命周期协调。
- `Core/`：Event Tap、剪贴板轮询与关联、设置、权限、登录启动和提示计数。
- `UI/`：原生 OSD 面板、菜单栏和设置界面。
- `Resources/`：英文与简体中文 `.strings` 本地化。
- `Tests/`：可执行的快捷键、剪贴板关联和提示计数单元测试。

## 许可

本项目遵循 MIT License。WinTips 的行为分析参考了对应开源仓库；macOS 实现独立编写，没有移植 Windows 专属代码，也没有复用 FluentFlyout 的 GPL 代码或资源。参见 [LICENSE](LICENSE)。
