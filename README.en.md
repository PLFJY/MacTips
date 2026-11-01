# MacTips

MacTips is a native menu bar utility for macOS 26 and later. It uses SwiftUI, AppKit, a listen-only Core Graphics Event Tap, and `NSPasteboard.changeCount` to show Copy, Paste, Cut, and Caps Lock hints. Clipboard payloads are never read, stored, or sent over the network.

## Build and run

Open `MacTips.xcodeproj` in Xcode 27 or later, run the `MacTips` scheme, then open Settings from the menu bar and enable MacTips under System Settings → Privacy & Security → Input Monitoring. Quit and relaunch if the permission change does not take effect immediately. Menu bar Test Tips exercises the real OSD without changing the clipboard or synthesizing key events.

```sh
xcodebuild -list -project MacTips.xcodeproj
xcodebuild -project MacTips.xcodeproj -scheme MacTips -configuration Debug -destination 'platform=macOS' build
xcodebuild -project MacTips.xcodeproj -scheme MacTips -configuration Release -destination 'platform=macOS' build
xcodebuild -project MacTips.xcodeproj -scheme MacTips -configuration Debug -destination 'platform=macOS' test
```

There are no third-party Swift packages. Settings use `UserDefaults`; login startup uses `SMAppService.mainApp`.

## Behavior and limitations

- Physical Command+C/V/X are observed without consuming events. Extra Shift, Option, or Control modifiers and autorepeat key-downs are ignored.
- Paste means the Command+V shortcut was pressed; it cannot confirm that the target accepted the paste.
- Copy and Cut check for a clipboard change for up to 1.2 seconds after the shortcut, then stop checking. The app only reads the change count, never clipboard payloads. A simultaneous write by another app can be misattributed.
- Clipboard changes from context menus and in-app copy buttons do not produce hints; there is no clipboard polling while idle.
- The OSD uses SwiftUI `.glassEffect` in a nonactivating, click-through `NSPanel`. Reduce Transparency uses an opaque fallback; Reduce Motion disables the slide animation.
- The menu bar icon can be hidden in Settings. Open MacTips again to bring the existing instance’s Settings forward; use the button in Settings to quit.
- Input Monitoring is required for global keyboard shortcuts and Caps Lock. The menu bar remains available without it. The app does not request Accessibility, Full Disk Access, or Screen Recording.
- Num Lock, Scroll Lock, and Insert are not implemented because macOS does not expose reliable universal state for those keys.

## Manual checks on a real Mac

Automated tests cover shortcut classification, clipboard correlation and timeouts, and counter state. They do not replace desktop compatibility checks:

- [ ] Finder file copy/paste and its Command+C then Command+Option+V move behavior.
- [ ] TextEdit selection copy/paste and Command+C with no selection.
- [ ] Firefox page copy, address-bar paste, and no hint for context-menu copy.
- [ ] Terminal Command+C interrupt versus copying selectable text.
- [ ] No hint for an app’s own Copy button, plus repeated shortcuts and clipboard-manager rewrites.
- [ ] Caps Lock on/off and any remapped-key behavior.
- [ ] Full-screen apps, multiple displays including negative-coordinate layouts, and display removal.
- [ ] Login startup and revoking/regranting Input Monitoring.
- [ ] Reduce Transparency and Reduce Motion accessibility settings.

## License

MIT. WinTips was consulted for behavior; the macOS implementation is original and does not port Windows-specific code or copy FluentFlyout GPL code/assets. See [LICENSE](LICENSE).
