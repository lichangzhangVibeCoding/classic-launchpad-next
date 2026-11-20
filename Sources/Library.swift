import Foundation
import AppKit

struct AppInfo: Equatable {
    let id: String
    let name: String
    let path: String
    let searchText: String
}

enum GridItem: Equatable {
    case app(String)
    case folder(String)

    var token: String {
        switch self {
        case .app(let id): return "app:" + id
        case .folder(let id): return "folder:" + id
        }
    }

    init?(token: String) {
        if token.hasPrefix("app:") {
            self = .app(String(token.dropFirst(4)))
        } else if token.hasPrefix("folder:") {
            self = .folder(String(token.dropFirst(7)))
        } else {
            return nil
        }
    }
}

struct FolderModel: Codable, Equatable {
    var name: String
    var apps: [String]
}

struct Layout: Codable, Equatable {
    var order: [String] = []
    var folders: [String: FolderModel] = [:]
    var hidden: [String] = []
}

enum OrderOps {
    static func place(tokens: [String], token: String, slot: Int) -> [String] {
        var list = tokens
        guard let from = list.firstIndex(of: token), from != slot else { return tokens }
        let item = list.remove(at: from)
        let dest = max(0, min(slot, list.count))
        list.insert(item, at: dest)
        return list
    }
}

enum SearchText {
    static func make(name: String) -> String {
        let folded = name.folding(
            options: [.diacriticInsensitive, .widthInsensitive, .caseInsensitive],
            locale: Locale(identifier: "zh_Hans")
        ).lowercased()
        let latin = latinize(name).lowercased()
        let syllables = latin.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        let joined = syllables.joined()
        let initials = syllables.compactMap(\.first).map(String.init).joined()
        return [folded, joined, initials].joined(separator: "\n")
    }

    static func matches(_ key: String, query: String) -> Bool {
        let q = query.folding(
            options: [.diacriticInsensitive, .widthInsensitive, .caseInsensitive],
            locale: Locale(identifier: "zh_Hans")
        )
        .lowercased()
        .filter { !$0.isWhitespace }
        if q.isEmpty { return true }
        for part in key.split(separator: "\n", omittingEmptySubsequences: false) where part.contains(q) {
            return true
        }
        return false
    }

    private static func latinize(_ string: String) -> String {
        let mutable = NSMutableString(string: string)
        CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
        return mutable as String
    }
}

enum AppScanner {
    private static let skipDirectories: Set<String> = [
        "Contents", "Frameworks", "Helpers", "PlugIns", "XPCServices",
        "Library", "Resources", "MacOS", "_CodeSignature", "node_modules",
        "Extensions", "SystemExtensions"
    ]
    private static let bannedIDs: Set<String> = [
        "local.tank.classic-launchpad",
        "local.tank.classic-launchpad-next"
    ]

    static func scan() -> [AppInfo] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        var found: [String: (info: AppInfo, rank: Int)] = [:]
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            home.appendingPathComponent("Applications", isDirectory: true)
        ]
        for root in roots where fm.fileExists(atPath: root.path) {
            walk(root, depth: 0, into: &found)
        }
        consider(URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"), into: &found)
        return found.values.map(\.info).sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private static func walk(_ dir: URL, depth: Int, into found: inout [String: (info: AppInfo, rank: Int)]) {
        guard depth <= 3 else { return }
        let fm = FileManager.default
        guard let children = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        for child in children {
            let name = child.lastPathComponent
            if name.hasPrefix(".") { continue }
            if child.pathExtension.lowercased() == "app" {
                consider(child, into: &found)
                continue
            }
            if skipDirectories.contains(name) { continue }
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: child.path, isDirectory: &isDir), isDir.boolValue else { continue }
            walk(child, depth: depth + 1, into: &found)
        }
    }

    private static func consider(_ url: URL, into found: inout [String: (info: AppInfo, rank: Int)]) {
        let bundle = Bundle(url: url)
        let info = bundle?.infoDictionary ?? [:]
        if isAgent(info) { return }
        let bundleID = bundle?.bundleIdentifier
        if let bundleID, bannedIDs.contains(bundleID) { return }
        let id = bundleID ?? url.path
        var name = FileManager.default.displayName(atPath: url.path)
        if name.lowercased().hasSuffix(".app") {
            name = String(name.dropLast(4))
        }
        if name.isEmpty { name = url.deletingPathExtension().lastPathComponent }
        if let localized = bundle?.localizedInfoDictionary?["CFBundleDisplayName"] as? String, !localized.isEmpty {
            name = localized
        }
        let app = AppInfo(id: id, name: name, path: url.path, searchText: SearchText.make(name: name))
        let rank = rank(of: url.path)
        if let existing = found[id] {
            if rank < existing.rank { found[id] = (app, rank) }
        } else {
            found[id] = (app, rank)
        }
    }

    private static func isAgent(_ info: [String: Any]) -> Bool {
        for key in ["LSUIElement", "LSBackgroundOnly"] {
            if let value = info[key] as? Bool, value { return true }
            if let value = info[key] as? NSNumber, value.intValue == 1 { return true }
            if let value = info[key] as? String, value == "1" { return true }
        }
        return false
    }

    private static func rank(of path: String) -> Int {
        if path.hasPrefix("/Applications/") { return 0 }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) { return 1 }
        if path.hasPrefix("/System/Applications/") { return 2 }
        return 3
    }
}

final class IconCache {
    static let shared = IconCache()
    private var images: [String: NSImage] = [:]

    func icon(for path: String) -> NSImage {
        if let image = images[path] { return image }
        let source = NSWorkspace.shared.icon(forFile: path)
        let pixels = 256
        let size = NSSize(width: pixels, height: pixels)
        let image: NSImage
        if let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) {
            rep.size = size
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            NSColor.clear.set()
            NSRect(origin: .zero, size: size).fill()
            source.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .sourceOver, fraction: 1)
            NSGraphicsContext.restoreGraphicsState()
            image = NSImage(size: size)
            image.addRepresentation(rep)
        } else {
            source.size = size
            image = source
        }
        images[path] = image
        return image
    }
}

final class Library {
    private(set) var apps: [String: AppInfo] = [:]
    private var layout = Layout()
    var persist = true
    private let fileURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClassicLaunchpadNext", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("layout.json")
        load()
    }

    var items: [GridItem] {
        layout.order.compactMap { token in
            guard let item = GridItem(token: token) else { return nil }
            switch item {
            case .app(let id):
                return apps[id] == nil ? nil : item
            case .folder(let id):
                guard let folder = layout.folders[id] else { return nil }
                let alive = folder.apps.contains { apps[$0] != nil }
                return alive ? item : nil
            }
        }
    }

    func folder(_ id: String) -> FolderModel? { layout.folders[id] }

    func hiddenApps() -> [AppInfo] {
        layout.hidden.compactMap { apps[$0] }.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    func reload(_ completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let scanned = AppScanner.scan()
            DispatchQueue.main.async {
                self.merge(scanned)
                completion()
            }
        }
    }

    func reloadSync() {
        merge(AppScanner.scan())
    }

    func search(_ query: String) -> [GridItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return items }
        var result: [GridItem] = []
        var seen = Set<String>()
        func consider(_ id: String) {
            guard seen.insert(id).inserted, let app = apps[id], !layout.hidden.contains(id) else { return }
            if SearchText.matches(app.searchText, query: trimmed) || app.name.localizedStandardContains(trimmed) {
                result.append(.app(id))
            }
        }
        for item in items {
            switch item {
            case .app(let id):
                consider(id)
            case .folder(let id):
                for appID in layout.folders[id]?.apps ?? [] { consider(appID) }
            }
        }
        return result
    }

    func place(token: String, at slot: Int, saveNow: Bool) {
        let current = items.map(\.token)
        let next = OrderOps.place(tokens: current, token: token, slot: slot)
        guard next != current else { return }
        layout.order = next
        if saveNow { save() }
    }

    func makeFolder(draggedApp: String, targetApp: String) -> String? {
        guard draggedApp != targetApp, let dragged = apps[draggedApp], let target = apps[targetApp] else { return nil }
        let name = folderName(for: dragged, and: target)
        let id = UUID().uuidString
        layout.folders[id] = FolderModel(name: name, apps: [targetApp, draggedApp])
        var list = items
        if let index = list.firstIndex(of: .app(targetApp)) {
            list[index] = .folder(id)
        } else {
            list.append(.folder(id))
        }
        list.removeAll { $0 == .app(draggedApp) }
        setItems(list, saveNow: true)
        return id
    }

    func add(appID: String, to folderID: String) {
        guard apps[appID] != nil, layout.folders[folderID] != nil else { return }
        if layout.folders[folderID]?.apps.contains(appID) == false {
            layout.folders[folderID]?.apps.append(appID)
        }
        var list = items
        list.removeAll { $0 == .app(appID) }
        setItems(list, saveNow: true)
    }

    func eject(appID: String, from folderID: String) {
        guard var folder = layout.folders[folderID] else { return }
        folder.apps.removeAll { $0 == appID }
        let alive = folder.apps.filter { apps[$0] != nil }
        var list = items
        if alive.count <= 1 {
            layout.folders.removeValue(forKey: folderID)
            if let index = list.firstIndex(of: .folder(folderID)) {
                if let only = alive.first {
                    list[index] = .app(only)
                    list.insert(.app(appID), at: index + 1)
                } else {
                    list[index] = .app(appID)
                }
            } else {
                if let only = alive.first { list.append(.app(only)) }
                list.append(.app(appID))
            }
        } else {
            folder.apps = alive
            layout.folders[folderID] = folder
            if let index = list.firstIndex(of: .folder(folderID)) {
                list.insert(.app(appID), at: index + 1)
            } else {
                list.append(.app(appID))
            }
        }
        setItems(list, saveNow: true)
    }

    func moveInsideFolder(appID: String, folderID: String, to index: Int) {
        guard var folder = layout.folders[folderID] else { return }
        let visible = folder.apps.filter { apps[$0] != nil }
        let next = OrderOps.place(tokens: visible, token: appID, slot: index)
        guard next != visible else { return }
        folder.apps = next + folder.apps.filter { apps[$0] == nil }
        layout.folders[folderID] = folder
    }

    func renameFolder(_ id: String, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, layout.folders[id] != nil else { return }
        layout.folders[id]?.name = trimmed
        save()
    }

    func hide(appID: String) {
        if !layout.hidden.contains(appID) { layout.hidden.append(appID) }
        layout.order.removeAll { $0 == "app:\(appID)" }
        for key in Array(layout.folders.keys) {
            layout.folders[key]?.apps.removeAll { $0 == appID }
        }
        pruneEmptyFolders()
        save()
    }

    func unhide(appID: String) {
        layout.hidden.removeAll { $0 == appID }
        if apps[appID] != nil {
            insertSorted(appID, into: &layout.order)
        }
        save()
    }

    func resetOrder() {
        arrangeByKind()
    }

    /// Puts every visible app in one flat list: kind first, then vendor, then name.
    func arrangeByKind() {
        let visible = apps.values
            .filter { !layout.hidden.contains($0.id) }
            .sorted { AppArrangement.key(for: $0) < AppArrangement.key(for: $1) }
        layout.folders = [:]
        layout.order = visible.map { "app:\($0.id)" }
        save()
    }

    func arrangementReport() -> String {
        var lines: [String] = []
        var current: AppArrangement.Kind?
        var count = 0
        var bucket: [String] = []
        func flush() {
            guard let current else { return }
            lines.append("\(AppArrangement.title(current)) (\(count))")
            lines.append(contentsOf: bucket)
            lines.append("")
        }
        for token in layout.order {
            guard let item = GridItem(token: token), case .app(let id) = item, let app = apps[id] else { continue }
            let key = AppArrangement.key(for: app)
            if current != key.kind {
                flush()
                current = key.kind
                count = 0
                bucket = []
            }
            count += 1
            bucket.append("  \(app.name)  [\(key.vendor)]")
        }
        flush()
        return lines.joined(separator: "\n")
    }

    func save() {
        guard persist else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(layout) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func setItems(_ list: [GridItem], saveNow: Bool) {
        layout.order = list.map(\.token)
        if saveNow { save() }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(Layout.self, from: data) else { return }
        layout = decoded
    }

    private func merge(_ scanned: [AppInfo]) {
        guard !scanned.isEmpty else { return }
        var map: [String: AppInfo] = [:]
        for app in scanned { map[app.id] = app }
        apps = map
        let valid = Set(map.keys)
        let hidden = layout.hidden.filter { valid.contains($0) }
        layout.hidden = hidden
        let hiddenSet = Set(hidden)
        var folders = layout.folders
        for key in folders.keys {
            folders[key]?.apps.removeAll { !valid.contains($0) || hiddenSet.contains($0) }
        }
        layout.folders = folders
        pruneEmptyFolders()

        var seen = Set<String>()
        var order: [String] = []
        for token in layout.order {
            guard let item = GridItem(token: token) else { continue }
            switch item {
            case .app(let id):
                if valid.contains(id), !layout.hidden.contains(id), seen.insert(token).inserted {
                    order.append(token)
                }
            case .folder(let id):
                if layout.folders[id] != nil, seen.insert(token).inserted {
                    order.append(token)
                }
            }
        }
        let placed = Set(order.compactMap { token -> String? in
            guard token.hasPrefix("app:") else { return nil }
            return String(token.dropFirst(4))
        })
        let inFolders = Set(layout.folders.values.flatMap(\.apps))
        let newcomers = scanned.filter {
            !placed.contains($0.id) && !inFolders.contains($0.id) && !layout.hidden.contains($0.id)
        }.sorted { AppArrangement.key(for: $0) < AppArrangement.key(for: $1) }
        for app in newcomers { insertSorted(app.id, into: &order) }
        layout.order = order
        save()
    }

    private func insertSorted(_ id: String, into order: inout [String]) {
        let token = "app:\(id)"
        guard !order.contains(token) else { return }
        guard let app = apps[id] else {
            order.append(token)
            return
        }
        let key = AppArrangement.key(for: app)
        var index = order.count
        for (i, existing) in order.enumerated() {
            guard let item = GridItem(token: existing), case .app(let otherID) = item,
                  let other = apps[otherID] else { continue }
            if key < AppArrangement.key(for: other) {
                index = i
                break
            }
        }
        order.insert(token, at: index)
    }

    private func pruneEmptyFolders() {
        let hidden = Set(layout.hidden)
        let known = apps
        let empty = layout.folders.filter { _, folder in
            !folder.apps.contains { known[$0] != nil && !hidden.contains($0) }
        }.map(\.key)
        for id in empty {
            layout.folders.removeValue(forKey: id)
            layout.order.removeAll { $0 == "folder:\(id)" }
        }
    }

    private func folderName(for first: AppInfo, and second: AppInfo) -> String {
        let left = AppArrangement.key(for: first)
        let right = AppArrangement.key(for: second)
        let base = left.kind == right.kind && left.kind != .other
            ? AppArrangement.title(left.kind)
            : "文件夹"
        let names = Set(layout.folders.values.map(\.name))
        if !names.contains(base) { return base }
        var index = 2
        while names.contains("\(base) \(index)") { index += 1 }
        return "\(base) \(index)"
    }
}
