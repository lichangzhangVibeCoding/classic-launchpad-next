import AppKit
import Carbon

extension Notification.Name {
    static let classicLaunchpadHotkey = Notification.Name("classicLaunchpadHotkey")
}

private func classicLaunchpadHotKeyHandler(_ next: EventHandlerCallRef?, _ event: EventRef?, _ user: UnsafeMutableRawPointer?) -> OSStatus {
    DispatchQueue.main.async {
        NotificationCenter.default.post(name: .classicLaunchpadHotkey, object: nil)
    }
    return noErr
}

enum Hotkey {
    private static var hotKey: EventHotKeyRef?
    private static var handler: EventHandlerRef?

    static func register() -> Bool {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installed = InstallEventHandler(GetApplicationEventTarget(), classicLaunchpadHotKeyHandler, 1, &spec, nil, &handler)
        guard installed == noErr else { return false }
        let id = EventHotKeyID(signature: OSType(0x4C504144), id: 1)
        let status = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(controlKey | optionKey),
            id,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
        return status == noErr
    }
}

private enum SelfCheck {
    static func run() {
        let weixin = SearchText.make(name: "微信")
        precondition(SearchText.matches(weixin, query: "wx"), weixin)
        precondition(SearchText.matches(weixin, query: "weixin"), weixin)
        precondition(SearchText.matches(SearchText.make(name: "系统设置"), query: "xitong"))
        precondition(SearchText.matches(SearchText.make(name: "Safari"), query: "saf"))
        let wechat = AppInfo(id: "com.tencent.xinWeChat", name: "微信", path: "", searchText: "")
        let qq = AppInfo(id: "com.tencent.qq", name: "QQ", path: "", searchText: "")
        let gpt = AppInfo(id: "com.openai.codex", name: "ChatGPT", path: "", searchText: "")
        let claude = AppInfo(id: "com.anthropic.claudefordesktop", name: "Claude", path: "", searchText: "")
        precondition(AppArrangement.key(for: wechat) < AppArrangement.key(for: qq))
        precondition(AppArrangement.key(for: wechat).kind == AppArrangement.key(for: qq).kind)
        precondition(AppArrangement.key(for: gpt).kind == AppArrangement.key(for: claude).kind)
        precondition(AppArrangement.key(for: qq) < AppArrangement.key(for: gpt))
        let moved = OrderOps.place(tokens: ["a", "b", "c", "d"], token: "b", slot: 2)
        precondition(moved == ["a", "c", "b", "d"], "\(moved)")
        let end = OrderOps.place(tokens: ["a", "b", "c", "d"], token: "a", slot: 3)
        precondition(end == ["b", "c", "d", "a"], "\(end)")
        let apps = AppScanner.scan()
        print("apps \(apps.count)")
        for app in apps.prefix(12) {
            print("- \(app.name)  \(app.id)")
        }
        print("check ok")
    }
}

private enum Preview {
    static func render() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let controller = LaunchpadController()
        let screen = NSScreen.main ?? NSScreen.screens[0]
        controller.preparePreview(size: screen.frame.size, screen: screen)
        let view = controller.root
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            fputs("preview failed: no bitmap\n", stderr)
            exit(1)
        }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            fputs("preview failed: no png\n", stderr)
            exit(1)
        }
        let url = URL(fileURLWithPath: "/tmp/launchpad-preview.png")
        try? data.write(to: url)
        print("preview \(Int(view.bounds.width))x\(Int(view.bounds.height)) apps \(controller.library.apps.count) -> \(url.path)")
    }

    static func renderFolder() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let controller = LaunchpadController()
        controller.library.persist = false
        let screen = NSScreen.main ?? NSScreen.screens[0]
        controller.preparePreview(size: screen.frame.size, screen: screen)
        let ids = controller.library.items.compactMap { item -> String? in
            if case .app(let id) = item { return id }
            return nil
        }
        guard ids.count >= 2, let folderID = controller.library.makeFolder(draggedApp: ids[1], targetApp: ids[0]) else {
            fputs("folder preview skipped\n", stderr)
            exit(1)
        }
        controller.openFolder(folderID, source: nil)
        let view = controller.root
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds),
              let data = {
                  view.cacheDisplay(in: view.bounds, to: rep)
                  return rep.representation(using: .png, properties: [:])
              }() else {
            fputs("folder preview failed\n", stderr)
            exit(1)
        }
        let url = URL(fileURLWithPath: "/tmp/launchpad-folder.png")
        try? data.write(to: url)
        print("folder preview -> \(url.path)")
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

if CommandLine.arguments.contains("--check") {
    SelfCheck.run()
    exit(0)
}
if CommandLine.arguments.contains("--preview") {
    Preview.render()
    exit(0)
}
if CommandLine.arguments.contains("--preview-folder") {
    Preview.renderFolder()
    exit(0)
}
if CommandLine.arguments.contains("--arrange") {
    let library = Library()
    library.reloadSync()
    library.arrangeByKind()
    print(library.arrangementReport())
    exit(0)
}

let delegateBox = LaunchpadController()
app.delegate = AppBox.shared
AppBox.shared.controller = delegateBox

final class AppBox: NSObject, NSApplicationDelegate {
    static let shared = AppBox()
    var controller: LaunchpadController?
    func applicationDidFinishLaunching(_ notification: Notification) {
        controller?.startStatusItem()
        let registered = Hotkey.register()
        if !registered {
            fputs("hotkey failed\n", stderr)
        }
        installMenu()
        if !CommandLine.arguments.contains("--background") {
            controller?.show()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controller?.show()
        return false
    }

    private func installMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "退出启动台", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        app.mainMenu = main
    }
}

app.run()
