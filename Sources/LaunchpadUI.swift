import AppKit
import QuartzCore
import ServiceManagement

struct Metrics {
    var search: CGRect
    var grid: CGRect
    var cell: CGSize
    var icon: CGFloat
    var dotsY: CGFloat
    let columns = 7
    let rows = 5

    var pageSize: Int { columns * rows }

    static func make(size: CGSize) -> Metrics {
        let short = size.height < 980
        let searchH: CGFloat = 38
        let searchTop: CGFloat = short ? 22 : 36
        let searchW = min(420, max(280, size.width * 0.28))
        let search = CGRect(x: (size.width - searchW) / 2, y: searchTop, width: searchW, height: searchH)
        let gridTop = searchTop + searchH + (short ? 16 : 26)
        let bottom: CGFloat = short ? 44 : 56
        let side = max(36, min(90, size.width * 0.048))
        let grid = CGRect(x: side, y: gridTop, width: max(0, size.width - side * 2), height: max(0, size.height - gridTop - bottom))
        let cell = CGSize(width: grid.width / 7, height: grid.height / 5)
        let icon = min(116, max(64, min(cell.width * 0.58, cell.height - 52)))
        let dotsY = size.height - (short ? 26 : 32)
        return Metrics(search: search, grid: grid, cell: cell, icon: icon, dotsY: dotsY)
    }

    func cellFrame(indexOnPage: Int) -> CGRect {
        let column = indexOnPage % columns
        let row = indexOnPage / columns
        return CGRect(
            x: grid.minX + CGFloat(column) * cell.width,
            y: grid.minY + CGFloat(row) * cell.height,
            width: cell.width,
            height: cell.height
        )
    }
}

struct Entry {
    var token: String
    var title: String
    var isFolder: Bool
    var icon: NSImage?
    var miniIcons: [NSImage]
    var appID: String?
    var folderID: String?
}

final class BorderlessWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class WallpaperView: NSView {
    var image: NSImage? {
        didSet {
            needsDisplay = true
        }
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        if let image {
            image.draw(in: bounds, from: .zero, operation: .copy, fraction: 1)
        } else {
            NSColor(calibratedWhite: 0.22, alpha: 1).setFill()
            bounds.fill()
        }
    }
}

final class FolderArt: NSView {
    var images: [NSImage] = [] { didSet { needsDisplay = true } }
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let box = NSBezierPath(roundedRect: bounds, xRadius: bounds.width * 0.23, yRadius: bounds.width * 0.23)
        NSColor.white.withAlphaComponent(0.32).setFill()
        box.fill()
        NSColor.white.withAlphaComponent(0.38).setStroke()
        box.lineWidth = 1
        box.stroke()

        let inset = bounds.width * 0.16
        let gap = bounds.width * 0.045
        let grid = bounds.insetBy(dx: inset, dy: inset)
        let side = (grid.width - gap * 2) / 3
        for index in images.indices.prefix(9) {
            let column = index % 3
            let row = index / 3
            let rect = CGRect(
                x: grid.minX + CGFloat(column) * (side + gap),
                y: grid.minY + CGFloat(row) * (side + gap),
                width: side,
                height: side
            )
            images[index].draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        }
    }
}

final class IconCell: NSView {
    weak var controller: LaunchpadController?
    let iconHolder = NSView()
    let imageView = NSImageView()
    let folderArt = FolderArt()
    var token = ""
    var appID: String?
    var folderID: String?
    var isInFolder = false
    var title = "" { didSet { needsDisplay = true } }
    var iconSize: CGFloat = 96
    var selected = false { didSet { needsDisplay = true } }
    var mergeHighlight = false { didSet { needsDisplay = true } }
    private var iconScale: CGFloat = 1
    private var labelTop: CGFloat = 0
    private var ringRect: CGRect = .zero
    private var hitRect: CGRect = .zero
    private var tracking: NSTrackingArea?

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
        iconHolder.wantsLayer = true
        iconHolder.layer?.shadowColor = NSColor.black.cgColor
        iconHolder.layer?.shadowOpacity = 0.3
        iconHolder.layer?.shadowRadius = 7
        iconHolder.layer?.shadowOffset = CGSize(width: 0, height: -2)
        iconHolder.layer?.masksToBounds = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.imageFrameStyle = .none
        folderArt.isHidden = true
        addSubview(iconHolder)
        iconHolder.addSubview(imageView)
        iconHolder.addSubview(folderArt)
    }

    required init?(coder: NSCoder) { nil }

    func configure(_ entry: Entry, iconSize: CGFloat) {
        token = entry.token
        title = entry.title
        appID = entry.appID
        folderID = entry.folderID
        self.iconSize = iconSize
        if entry.isFolder {
            imageView.isHidden = true
            folderArt.isHidden = false
            folderArt.images = entry.miniIcons
        } else {
            imageView.isHidden = false
            folderArt.isHidden = true
            imageView.image = entry.icon
        }
        needsLayout = true
    }

    func setScale(_ value: CGFloat, animated: Bool) {
        iconScale = value
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.14
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                context.allowsImplicitAnimation = true
                layoutSubtreeIfNeeded()
            }
        } else {
            needsLayout = true
            layoutSubtreeIfNeeded()
        }
    }

    func setLifted(_ lifted: Bool) {
        iconHolder.layer?.shadowOpacity = lifted ? 0.48 : 0.3
        iconHolder.layer?.shadowRadius = lifted ? 18 : 7
        setScale(lifted ? 1.1 : 1, animated: true)
    }

    var iconBounds: CGRect { ringRect.insetBy(dx: 11, dy: 11) }

    override func layout() {
        super.layout()
        let labelH: CGFloat = 36
        let gap: CGFloat = 7
        let total = iconSize + gap + labelH
        let y = max(0, (bounds.height - total) / 2)
        let base = CGRect(x: (bounds.width - iconSize) / 2, y: y, width: iconSize, height: iconSize)
        let scaledW = base.width * iconScale
        let scaledH = base.height * iconScale
        iconHolder.frame = CGRect(x: base.midX - scaledW / 2, y: base.midY - scaledH / 2, width: scaledW, height: scaledH)
        imageView.frame = iconHolder.bounds
        folderArt.frame = iconHolder.bounds
        labelTop = base.maxY + gap
        ringRect = base.insetBy(dx: -12, dy: -12)
        let insetX = min(18, max(10, bounds.width * 0.07))
        let insetY = min(8, max(4, bounds.height * 0.028))
        let top = max(insetY, base.minY - 8)
        let bottom = min(bounds.height - insetY, labelTop + 38)
        hitRect = CGRect(
            x: insetX,
            y: top,
            width: max(0, bounds.width - insetX * 2),
            height: max(base.height, bottom - top)
        )
        needsDisplay = true
        if window != nil { updateTrackingAreas() }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, alphaValue > 0.01, hitRect.width > 1 else { return nil }
        return hitRect.contains(convert(point, from: superview)) ? self : nil
    }

    override func draw(_ dirtyRect: NSRect) {
        if selected || mergeHighlight {
            let color = NSColor.white.withAlphaComponent(mergeHighlight ? 0.36 : 0.22)
            color.setFill()
            NSBezierPath(roundedRect: ringRect, xRadius: 22, yRadius: 22).fill()
        }
        let rect = CGRect(x: 8, y: labelTop, width: max(0, bounds.width - 16), height: 36)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.72)
        shadow.shadowBlurRadius = 3
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byTruncatingTail
        style.maximumLineHeight = 16
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12.5, weight: .medium),
            .foregroundColor: NSColor.white,
            .shadow: shadow,
            .paragraphStyle: style
        ]
        (title as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: attributes)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: hitRect, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        guard controller?.dragToken == nil else { return }
        setScale(1.06, animated: true)
    }

    override func mouseExited(with event: NSEvent) {
        guard controller?.dragToken == nil else { return }
        setScale(1, animated: true)
    }

    override func mouseDown(with event: NSEvent) {
        controller?.handleMouse(on: self, event: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        controller?.presentMenu(for: self, event: event)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func open() {
        if let folderID {
            controller?.openFolder(folderID, source: self)
        } else if let appID {
            controller?.launch(appID, source: self)
        }
    }
}

final class SearchBar: NSView {
    let field = NSTextField()
    let icon = NSImageView()
    let clearButton = NSButton()
    var onClear: (() -> Void)?

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        let symbol = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "搜索")
        symbol?.isTemplate = true
        symbol?.size = NSSize(width: 15, height: 15)
        icon.image = symbol
        icon.contentTintColor = .secondaryLabelColor
        let clearImage = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "清除")
        clearImage?.isTemplate = true
        clearImage?.size = NSSize(width: 14, height: 14)
        clearButton.image = clearImage
        clearButton.isBordered = false
        clearButton.contentTintColor = .tertiaryLabelColor
        clearButton.target = self
        clearButton.action = #selector(clear)
        clearButton.isHidden = true
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 15)
        field.cell?.usesSingleLineMode = true
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.lineBreakMode = .byTruncatingTail
        addSubview(icon)
        addSubview(field)
        addSubview(clearButton)
        applyAppearance()
    }

    required init?(coder: NSCoder) { nil }

    var isDark: Bool {
        effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    func applyAppearance() {
        let dark = isDark
        field.textColor = dark ? .white : NSColor(calibratedWhite: 0.12, alpha: 1)
        let placeholder = dark ? NSColor.white.withAlphaComponent(0.5) : NSColor.black.withAlphaComponent(0.42)
        field.placeholderAttributedString = NSAttributedString(
            string: "搜索",
            attributes: [
                .foregroundColor: placeholder,
                .font: NSFont.systemFont(ofSize: 15)
            ]
        )
        icon.contentTintColor = dark ? NSColor.white.withAlphaComponent(0.7) : NSColor.black.withAlphaComponent(0.45)
        clearButton.contentTintColor = dark ? NSColor.white.withAlphaComponent(0.55) : NSColor.black.withAlphaComponent(0.35)
        needsDisplay = true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyAppearance()
    }

    override func layout() {
        super.layout()
        let h = bounds.height
        icon.frame = CGRect(x: 12, y: (h - 16) / 2, width: 16, height: 16)
        clearButton.frame = CGRect(x: bounds.width - 30, y: (h - 18) / 2, width: 18, height: 18)
        field.frame = CGRect(x: 34, y: (h - 22) / 2, width: max(0, bounds.width - 70), height: 22)
    }

    override func draw(_ dirtyRect: NSRect) {
        let dark = isDark
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(dark ? 0.28 : 0.16)
        shadow.shadowBlurRadius = 12
        shadow.shadowOffset = NSSize(width: 0, height: -4)
        shadow.set()
        let fill = dark ? NSColor.white.withAlphaComponent(0.16) : NSColor.white.withAlphaComponent(0.9)
        fill.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 12, yRadius: 12).fill()
        NSShadow().set()
        if !dark {
            NSColor.black.withAlphaComponent(0.06).setStroke()
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 12, yRadius: 12)
            path.lineWidth = 1
            path.stroke()
        }
    }

    func setShowsClear(_ shows: Bool) {
        clearButton.isHidden = !shows
    }

    @objc private func clear() { onClear?() }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(field)
    }
}

final class PageDots: NSView {
    var count = 0 { didSet { needsDisplay = true } }
    var index = 0 { didSet { needsDisplay = true } }
    var onPick: ((Int) -> Void)?
    var onMiss: (() -> Void)?
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard count > 1 else { return }
        let active: CGFloat = 8
        let idle: CGFloat = 6
        let gap: CGFloat = 10
        var total: CGFloat = 0
        for i in 0..<count { total += (i == index ? active : idle) }
        total += CGFloat(count - 1) * gap
        var x = (bounds.width - total) / 2
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
        shadow.shadowBlurRadius = 2
        shadow.shadowOffset = .zero
        shadow.set()
        for i in 0..<count {
            let side = i == index ? active : idle
            let rect = CGRect(x: x, y: (bounds.height - side) / 2, width: side, height: side)
            let color = i == index ? NSColor.white : NSColor.white.withAlphaComponent(0.42)
            color.setFill()
            NSBezierPath(ovalIn: rect).fill()
            x += side + gap
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard count > 1 else {
            onMiss?()
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        let active: CGFloat = 8
        let idle: CGFloat = 6
        let gap: CGFloat = 10
        var total: CGFloat = 0
        for i in 0..<count { total += (i == index ? active : idle) }
        total += CGFloat(count - 1) * gap
        var x = (bounds.width - total) / 2
        for i in 0..<count {
            let side = i == index ? active : idle
            let rect = CGRect(x: x - 4, y: 0, width: side + 8, height: bounds.height)
            if rect.contains(point) {
                onPick?(i)
                return
            }
            x += side + gap
        }
        onMiss?()
    }
}

final class DimView: NSView {
    var onClose: (() -> Void)?
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.46).setFill()
        bounds.fill()
    }
    override func mouseDown(with event: NSEvent) { onClose?() }
}

final class FolderPanel: NSView {
    var onMouseDown: (() -> Void)?
    override var isFlipped: Bool { true }

    override func mouseDown(with event: NSEvent) { onMouseDown?() }
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 28, yRadius: 28)
        NSColor(calibratedWhite: 0.12, alpha: 1).setFill()
        path.fill()
        NSColor.white.withAlphaComponent(0.3).setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

final class CenterLabel: NSView {
    var title = "" { didSet { needsDisplay = true } }
    var onClick: (() -> Void)?
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.8)
        shadow.shadowBlurRadius = 4
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byTruncatingTail
        let font = NSFont.systemFont(ofSize: 28, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
            .shadow: shadow,
            .paragraphStyle: style
        ]
        let text = title as NSString
        let size = text.size(withAttributes: attributes)
        let rect = CGRect(
            x: 8,
            y: max(0, (bounds.height - size.height) / 2),
            width: max(0, bounds.width - 16),
            height: size.height
        )
        text.draw(in: rect, withAttributes: attributes)
    }

    override func mouseDown(with event: NSEvent) { onClick?() }
}

final class RootView: NSView {
    var onScroll: ((NSEvent) -> Void)?
    var onMouseDown: (() -> Void)?
    override var isFlipped: Bool { true }
    override func scrollWheel(with event: NSEvent) {
        if let onScroll {
            onScroll(event)
        } else {
            nextResponder?.scrollWheel(with: event)
        }
    }
    override func mouseDown(with event: NSEvent) {
        onMouseDown?()
    }
}

final class LaunchpadController: NSObject, NSTextFieldDelegate, NSWindowDelegate {
    let library = Library()
    let window: BorderlessWindow
    let root = RootView()
    let wallpaper = WallpaperView()
    let canvas = RootView()
    let side = RootView()
    let clip = RootView()
    let search = SearchBar()
    let dots = PageDots()
    let emptyLabel = NSTextField(labelWithString: "")
    let dragLayer = RootView()
    let folderOverlay = RootView()
    let folderDim = DimView()
    let folderPanel = FolderPanel()
    let folderClip = RootView()
    let folderGrid = RootView()
    let folderSide = RootView()
    let folderTitle = NSTextField()
    let folderNameLabel = CenterLabel()
    let folderDots = PageDots()

    var metrics = Metrics.make(size: NSSize(width: 1440, height: 900))
    var page = 0
    var query = ""
    var selection: Int?
    var keyboardActive = false
    var visible = false
    var dragToken: String?
    var openFolderID: String?
    var folderPage = 0
    var folderSelection: Int?
    private var folderOffset: CGFloat = 0
    private var folderRaw: CGFloat = 0
    private var folderSideIndex: Int?
    private var folderTracking = false
    private var folderSpringing = false
    private var folderSpringTarget: CGFloat = 0
    private var folderSpringVelocity: CGFloat = 0
    private var folderSpringCommit: Int?
    private var folderSpringStarted = Date()
    private var folderLastTick = Date()
    private var folderPagerTimer: Timer?
    private var folderMotionTimer: Timer?
    private var folderMotion = false
    private var folderClosing = false
    private var folderSource = CGPoint.zero
    private var wallpaperCache: NSImage?
    private var wallpaperScreenID: String?
    private var scrollAccumX: CGFloat = 0
    private var scrollAccumY: CGFloat = 0
    private var scrollAxisLocked = false
    private var scrollIsHorizontal = false
    private var pageOffset: CGFloat = 0
    private var rawOffset: CGFloat = 0
    private var sidePage: Int?
    private var trackingPage = false
    private var springing = false
    private var springTarget: CGFloat = 0
    private var springVelocity: CGFloat = 0
    private var springCommit: Int?
    private var springStarted = Date()
    private var lastSpringTick = Date()
    private var pagerTimer: Timer?
    private var fingerVelocity: CGFloat = 0
    private var lastScrollTime: TimeInterval = 0
    private var allowsAnimation = true
    private var dragGrab = CGPoint.zero
    private var lastSlot: Int?
    private var lastFolderSlot: Int?
    private var mergeToken: String?
    private var folderWillEject = false
    private var edgeStamp: Date?
    private var lastPageTurn = Date.distantPast
    private var lastDragPoint = CGPoint.zero
    private var statusItem: NSStatusItem?
    private var openingFolder = false
    private var committingTitle = false

    override init() {
        window = BorderlessWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        super.init()
        configureWindow()
        configureViews()
    }

    func startStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let image = NSImage(systemSymbolName: "square.grid.3x3", accessibilityDescription: "启动台")?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        item.button?.image = image
        item.button?.target = self
        item.button?.action = #selector(statusClicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
        library.reload { }
        NotificationCenter.default.addObserver(self, selector: #selector(hotkeyPressed), name: .classicLaunchpadHotkey, object: nil)
    }

    func show() {
        if visible {
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(search.field)
            return
        }
        if library.apps.isEmpty {
            library.reload { [weak self] in self?.present() }
        } else {
            present()
            library.reload { [weak self] in
                guard let self, self.visible, self.dragToken == nil else { return }
                if self.trackingPage || self.springing || self.folderTracking || self.folderSpringing || self.folderMotion { return }
                self.refresh(direction: 0)
            }
        }
    }

    func hide(animated: Bool) {
        guard visible else { return }
        visible = false
        stopPager()
        query = ""
        search.field.stringValue = ""
        search.setShowsClear(false)
        keyboardActive = false
        selection = nil
        dragToken = nil
        openFolderID = nil
        folderOverlay.isHidden = true
        let finish = {
            self.window.orderOut(nil)
            self.window.alphaValue = 1
        }
        if animated && allowsAnimation {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                self.window.animator().alphaValue = 0
            } completionHandler: {
                finish()
            }
        } else {
            finish()
        }
    }

    func toggle() {
        if visible { hide(animated: true) } else { show() }
    }

    func preparePreview(size: CGSize, screen: NSScreen) {
        allowsAnimation = false
        library.reloadSync()
        window.setFrame(NSRect(origin: .zero, size: size), display: true)
        relayoutFrames()
        let dark = isDark
        let url = NSWorkspace.shared.desktopImageURL(for: screen)
        wallpaper.image = WallpaperRenderer.render(url: url, pointSize: size, scale: screen.backingScaleFactor, dark: dark)
        refresh(direction: 0)
        root.layoutSubtreeIfNeeded()
        root.displayIfNeeded()
    }

    func openFolder(_ id: String, source: IconCell?) {
        guard library.folder(id) != nil, !folderClosing else { return }
        if let source, source.window != nil {
            let local = source.iconBounds.width > 2
                ? CGPoint(x: source.iconBounds.midX, y: source.iconBounds.midY)
                : CGPoint(x: source.bounds.midX, y: source.bounds.midY)
            folderSource = folderOverlay.convert(local, from: source)
        } else {
            folderSource = CGPoint(x: root.bounds.midX, y: root.bounds.midY)
        }
        stopPager()
        stopFolderPager()
        openFolderID = id
        folderPage = 0
        folderSelection = nil
        openingFolder = true
        refresh(direction: 0)
        openingFolder = false
    }

    func launch(_ id: String, source: IconCell?) {
        guard let app = library.apps[id] else { return }
        source?.setScale(1.16, animated: true)
        let url = URL(fileURLWithPath: app.path)
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        hide(animated: true)
        NSWorkspace.shared.openApplication(at: url, configuration: config, completionHandler: nil)
    }

    func handleMouse(on cell: IconCell, event: NSEvent) {
        if !query.isEmpty {
            trackClick(cell)
            return
        }
        let start = event.locationInWindow
        cell.setScale(0.94, animated: true)
        var dragged = false
        while true {
            guard let next = window.nextEvent(
                matching: [.leftMouseDragged, .leftMouseUp],
                until: Date().addingTimeInterval(0.1),
                inMode: .eventTracking,
                dequeue: true
            ) else {
                if dragged, !cell.isInFolder { checkEdgeWhileStationary() }
                continue
            }
            if next.type == .leftMouseUp { break }
            let point = next.locationInWindow
            if !dragged, hypot(point.x - start.x, point.y - start.y) > 5 {
                dragged = true
                beginDrag(cell, event: next)
            }
            if dragged { updateDrag(cell, event: next) }
        }
        if dragged {
            endDrag(cell)
        } else {
            cell.setScale(1, animated: true)
            cell.open()
        }
    }

    func presentMenu(for cell: IconCell, event: NSEvent) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        if cell.folderID == nil {
            let open = NSMenuItem(title: "打开", action: #selector(menuOpen(_:)), keyEquivalent: "")
            open.target = self
            open.representedObject = cell
            menu.addItem(open)
            let reveal = NSMenuItem(title: "在访达中显示", action: #selector(menuReveal(_:)), keyEquivalent: "")
            reveal.target = self
            reveal.representedObject = cell
            menu.addItem(reveal)
        } else {
            let rename = NSMenuItem(title: "重新命名", action: #selector(menuRenameFolder(_:)), keyEquivalent: "")
            rename.target = self
            rename.representedObject = cell
            menu.addItem(rename)
        }
        if cell.isInFolder, let appID = cell.appID, let folderID = openFolderID {
            let eject = NSMenuItem(title: "移出文件夹", action: #selector(menuEject(_:)), keyEquivalent: "")
            eject.target = self
            eject.representedObject = ["app": appID, "folder": folderID]
            menu.addItem(eject)
        }
        if let appID = cell.appID {
            menu.addItem(.separator())
            let hide = NSMenuItem(title: "从启动台移除", action: #selector(menuHide(_:)), keyEquivalent: "")
            hide.target = self
            hide.representedObject = appID
            menu.addItem(hide)
        }
        NSMenu.popUpContextMenu(menu, with: event, for: cell)
    }

    // MARK: - Private setup

    private func configureWindow() {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .popUpMenu
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle, .transient]
        window.isMovable = false
        window.isMovableByWindowBackground = false
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.animationBehavior = .none
        window.delegate = self
        window.contentView = root
        root.autoresizingMask = [.width, .height]
    }

    private func configureViews() {
        wallpaper.wantsLayer = true
        wallpaper.layer?.backgroundColor = NSColor(calibratedWhite: 0.2, alpha: 1).cgColor
        clip.wantsLayer = true
        clip.layer?.masksToBounds = true
        dragLayer.isHidden = true
        folderOverlay.isHidden = true
        folderPanel.wantsLayer = true
        folderPanel.layer?.cornerRadius = 28
        folderPanel.layer?.masksToBounds = true
        folderTitle.isEditable = true
        folderTitle.isSelectable = true
        folderTitle.isBordered = false
        folderTitle.isBezeled = false
        folderTitle.drawsBackground = false
        folderTitle.focusRingType = .none
        folderTitle.alignment = .center
        folderTitle.textColor = .white
        folderTitle.font = .systemFont(ofSize: 28, weight: .medium)
        let titleShadow = NSShadow()
        titleShadow.shadowColor = NSColor.black.withAlphaComponent(0.75)
        titleShadow.shadowBlurRadius = 4
        titleShadow.shadowOffset = NSSize(width: 0, height: -1)
        folderTitle.shadow = titleShadow
        folderTitle.isHidden = true
        folderNameLabel.onClick = { [weak self] in self?.beginFolderRename() }
        folderTitle.delegate = self
        folderTitle.target = self
        folderTitle.action = #selector(commitFolderTitle)
        emptyLabel.alignment = .center
        emptyLabel.textColor = NSColor.white.withAlphaComponent(0.86)
        emptyLabel.font = .systemFont(ofSize: 20, weight: .medium)
        emptyLabel.isHidden = true
        let emptyShadow = NSShadow()
        emptyShadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
        emptyShadow.shadowBlurRadius = 3
        emptyLabel.shadow = emptyShadow

        root.addSubview(wallpaper)
        root.addSubview(clip)
        clip.addSubview(side)
        clip.addSubview(canvas)
        side.isHidden = true
        root.addSubview(emptyLabel)
        root.addSubview(dots)
        root.addSubview(search)
        root.addSubview(dragLayer)
        root.addSubview(folderOverlay)
        folderOverlay.addSubview(folderDim)
        folderOverlay.addSubview(folderPanel)
        folderClip.wantsLayer = true
        folderClip.layer?.masksToBounds = true
        folderPanel.addSubview(folderClip)
        folderClip.addSubview(folderSide)
        folderClip.addSubview(folderGrid)
        folderSide.isHidden = true
        folderPanel.addSubview(folderDots)
        folderOverlay.addSubview(folderTitle)
        folderOverlay.addSubview(folderNameLabel)

        search.field.delegate = self
        search.onClear = { [weak self] in
            self?.search.field.stringValue = ""
            self?.setQuery("")
            self?.window.makeFirstResponder(self?.search.field)
        }
        dots.onPick = { [weak self] index in self?.goToPage(index) }
        folderDots.onPick = { [weak self] index in self?.goToFolderPage(index) }
        let background: () -> Void = { [weak self] in
            self?.backgroundClick()
        }
        folderDim.onClose = background
        folderPanel.onMouseDown = background
        root.onMouseDown = background
        clip.onMouseDown = background
        canvas.onMouseDown = background
        side.onMouseDown = background
        folderGrid.onMouseDown = background
        folderSide.onMouseDown = background
        dots.onMiss = background
        folderDots.onMiss = background
        root.onScroll = { [weak self] event in self?.handleScroll(event) }
    }

    private func present() {
        guard let screen = screenUnderMouse() else { return }
        visible = true
        window.setFrame(screen.frame, display: true)
        relayoutFrames()
        refresh(direction: 0)
        loadWallpaper(for: screen)
        window.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        window.makeFirstResponder(search.field)
        tuneFieldEditor()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            self.window.animator().alphaValue = 1
        }
    }

    private func screenUnderMouse() -> NSScreen? {
        let point = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
    }

    private var isDark: Bool {
        root.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private func loadWallpaper(for screen: NSScreen) {
        let key = "\(screen.frame.origin.x),\(screen.frame.origin.y),\(screen.frame.size),\(isDark)"
        if wallpaperScreenID == key, let wallpaperCache {
            wallpaper.image = wallpaperCache
            return
        }
        let url = NSWorkspace.shared.desktopImageURL(for: screen)
        let size = screen.frame.size
        let scale = screen.backingScaleFactor
        let dark = isDark
        DispatchQueue.global(qos: .userInitiated).async {
            let image = WallpaperRenderer.render(url: url, pointSize: size, scale: scale, dark: dark)
            DispatchQueue.main.async {
                guard self.visible else { return }
                self.wallpaperCache = image
                self.wallpaperScreenID = key
                self.wallpaper.wantsLayer = true
                let fade = CATransition()
                fade.duration = 0.25
                fade.type = .fade
                self.wallpaper.layer?.add(fade, forKey: "fade")
                self.wallpaper.image = image
            }
        }
    }

    private func relayoutFrames() {
        let size = root.bounds.size
        guard size.width > 10, size.height > 10 else { return }
        metrics = Metrics.make(size: size)
        wallpaper.frame = root.bounds
        clip.frame = root.bounds
        if springing || trackingPage {
            layoutStrip()
        } else {
            canvas.frame = root.bounds
            side.frame = root.bounds
        }
        dragLayer.frame = root.bounds
        folderOverlay.frame = root.bounds
        folderDim.frame = root.bounds
        search.frame = metrics.search
        dots.frame = CGRect(x: 0, y: metrics.dotsY - 12, width: size.width, height: 24)
        emptyLabel.frame = CGRect(x: 0, y: metrics.grid.midY - 16, width: size.width, height: 32)
        search.applyAppearance()
    }

    private func activeList() -> [GridItem] {
        query.isEmpty ? library.items : library.search(query)
    }

    private func refresh(direction: Int) {
        if springing || trackingPage || pageOffset != 0 || sidePage != nil {
            stopPager()
        }
        relayoutFrames()
        let list = activeList()
        let pages = max(1, Int(ceil(Double(max(list.count, 1)) / Double(metrics.pageSize))))
        if list.isEmpty { page = 0 }
        if page >= pages { page = pages - 1 }
        if page < 0 { page = 0 }
        dots.count = list.isEmpty ? 0 : pages
        dots.index = page
        dots.isHidden = pages <= 1
        dots.needsDisplay = true
        emptyLabel.isHidden = !list.isEmpty
        emptyLabel.stringValue = query.isEmpty ? "没有应用程序" : "没有结果"
        search.setShowsClear(!query.isEmpty)

        if dragToken != nil {
            syncCanvas(animated: true)
        } else {
            rebuildCanvas()
        }
        _ = direction
        updateSelectionAppearance()
        layoutFolder()
    }

    private func entries(for item: GridItem) -> Entry? {
        switch item {
        case .app(let id):
            guard let app = library.apps[id] else { return nil }
            return Entry(token: item.token, title: app.name, isFolder: false, icon: IconCache.shared.icon(for: app.path), miniIcons: [], appID: id, folderID: nil)
        case .folder(let id):
            guard let folder = library.folder(id) else { return nil }
            let ids = folder.apps.filter { library.apps[$0] != nil }
            let minis = ids.prefix(9).compactMap { library.apps[$0].map { IconCache.shared.icon(for: $0.path) } }
            return Entry(token: item.token, title: folder.name, isFolder: true, icon: nil, miniIcons: minis, appID: nil, folderID: id)
        }
    }

    private func pageCount() -> Int {
        let count = activeList().count
        return max(1, Int(ceil(Double(max(count, 1)) / Double(metrics.pageSize))))
    }

    private func entries(on pageIndex: Int) -> [Entry] {
        let list = activeList()
        let start = pageIndex * metrics.pageSize
        guard pageIndex >= 0, start < list.count else { return [] }
        let slice = list[start..<min(list.count, start + metrics.pageSize)]
        return slice.compactMap { entries(for: $0) }
    }

    private func pageEntries() -> [Entry] {
        entries(on: page)
    }

    private func fill(_ host: NSView, pageIndex: Int) {
        for view in host.subviews { view.removeFromSuperview() }
        for (index, entry) in entries(on: pageIndex).enumerated() {
            let cell = IconCell()
            cell.controller = self
            cell.iconSize = metrics.icon
            cell.frame = metrics.cellFrame(indexOnPage: index)
            cell.configure(entry, iconSize: metrics.icon)
            host.addSubview(cell)
        }
    }

    private func rebuildCanvas() {
        for view in canvas.subviews where (view as? IconCell)?.token != dragToken {
            view.removeFromSuperview()
        }
        for (index, entry) in pageEntries().enumerated() where entry.token != dragToken {
            let cell = IconCell()
            cell.controller = self
            cell.iconSize = metrics.icon
            cell.frame = metrics.cellFrame(indexOnPage: index)
            cell.configure(entry, iconSize: metrics.icon)
            canvas.addSubview(cell)
        }
    }

    private func syncCanvas(animated: Bool) {
        let entries = pageEntries()
        var existing: [String: IconCell] = [:]
        for case let cell as IconCell in canvas.subviews {
            existing[cell.token] = cell
        }
        var keep = Set<String>()
        for (index, entry) in entries.enumerated() where entry.token != dragToken {
            keep.insert(entry.token)
            let frame = metrics.cellFrame(indexOnPage: index)
            if let cell = existing[entry.token] {
                cell.configure(entry, iconSize: metrics.icon)
                if animated && allowsAnimation {
                    NSAnimationContext.runAnimationGroup { context in
                        context.duration = 0.22
                        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                        cell.animator().frame = frame
                    }
                } else {
                    cell.frame = frame
                }
            } else {
                let cell = IconCell()
                cell.controller = self
                cell.frame = frame
                cell.configure(entry, iconSize: metrics.icon)
                canvas.addSubview(cell)
            }
        }
        for (token, cell) in existing where !keep.contains(token) && token != dragToken {
            cell.removeFromSuperview()
        }
    }

    /// Slides the icon pages with the fingers, then glides into place. Search and dots stay still.
    private func layoutStrip() {
        let bounds = clip.bounds
        guard bounds.width > 1, bounds.height > 1 else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        canvas.frame = CGRect(x: pageOffset, y: 0, width: bounds.width, height: bounds.height)
        if let sidePage {
            let direction: CGFloat = sidePage > page ? 1 : -1
            side.frame = CGRect(x: pageOffset + direction * bounds.width, y: 0, width: bounds.width, height: bounds.height)
            side.isHidden = false
        } else {
            side.isHidden = true
        }
        CATransaction.commit()
    }

    private func syncNeighbor() {
        let want: Int?
        if pageOffset < -1, page + 1 < pageCount() {
            want = page + 1
        } else if pageOffset > 1, page > 0 {
            want = page - 1
        } else {
            want = nil
        }
        guard want != sidePage else {
            layoutStrip()
            return
        }
        sidePage = want
        if let want {
            fill(side, pageIndex: want)
        } else {
            side.subviews.forEach { $0.removeFromSuperview() }
        }
        layoutStrip()
    }

    private func swipeGain() -> CGFloat {
        max(1.35, clip.bounds.width / 720)
    }

    private func resist(_ raw: CGFloat) -> CGFloat {
        let width = max(clip.bounds.width, 1)
        let lower: CGFloat = page > 0 ? -width : 0
        let upper: CGFloat = page + 1 < pageCount() ? width : 0
        if raw < lower { return lower - rubberBand(lower - raw) }
        if raw > upper { return upper + rubberBand(raw - upper) }
        return raw
    }

    private func rubberBand(_ distance: CGFloat) -> CGFloat {
        let limit: CGFloat = 128
        return limit * (1 - exp(-distance / 260))
    }

    private func stopPager() {
        pagerTimer?.invalidate()
        pagerTimer = nil
        springing = false
        trackingPage = false
        springCommit = nil
        springVelocity = 0
        fingerVelocity = 0
        pageOffset = 0
        rawOffset = 0
        sidePage = nil
        side.subviews.forEach { $0.removeFromSuperview() }
        side.isHidden = true
        canvas.frame.origin.x = 0
        resetScrollGesture()
    }

    private func beginSlide(to newPage: Int) {
        guard newPage != page else { return }
        guard allowsAnimation else {
            page = newPage
            refresh(direction: 0)
            return
        }
        let width = max(clip.bounds.width, 1)
        sidePage = newPage
        fill(side, pageIndex: newPage)
        let direction: CGFloat = newPage > page ? -1 : 1
        springVelocity = direction * width * 1.35
        startSpring(to: direction * width, commit: newPage)
    }

    private func startSpring(to target: CGFloat, commit: Int?) {
        springTarget = target
        springCommit = commit
        springing = true
        trackingPage = false
        springStarted = Date()
        lastSpringTick = springStarted
        layoutStrip()
        dots.index = commit ?? page
        dots.needsDisplay = true
        pagerTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            self?.stepSpring()
        }
        pagerTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stepSpring() {
        guard springing else { return }
        let now = Date()
        var dt = CGFloat(now.timeIntervalSince(lastSpringTick))
        lastSpringTick = now
        if dt <= 0 || dt > 1.0 / 30 { dt = 1.0 / 120 }
        let stiffness: CGFloat = 460
        let damping: CGFloat = 43
        springVelocity += (-stiffness * (pageOffset - springTarget) - damping * springVelocity) * dt
        pageOffset += springVelocity * dt
        layoutStrip()
        let arrived = abs(pageOffset - springTarget) < 8 && abs(springVelocity) < 90
        if arrived || now.timeIntervalSince(springStarted) > 0.7 {
            finishSpring()
        }
    }

    private func finishSpring() {
        pagerTimer?.invalidate()
        pagerTimer = nil
        let landed = springCommit
        springing = false
        trackingPage = false
        springCommit = nil
        springVelocity = 0
        fingerVelocity = 0
        pageOffset = 0
        rawOffset = 0
        sidePage = nil
        side.subviews.forEach { $0.removeFromSuperview() }
        side.isHidden = true
        if let landed { page = landed }
        canvas.frame = clip.bounds
        rebuildCanvas()
        let pages = pageCount()
        dots.count = activeList().isEmpty ? 0 : pages
        dots.index = page
        dots.needsDisplay = true
        updateSelectionAppearance()
        resetScrollGesture()
    }

    private func updateSelectionAppearance() {
        let list = activeList()
        let token: String? = {
            guard keyboardActive, let selection, list.indices.contains(selection) else { return nil }
            let item = list[selection]
            let itemPage = selection / metrics.pageSize
            return itemPage == page ? item.token : nil
        }()
        for case let cell as IconCell in canvas.subviews {
            cell.selected = cell.token == token
        }
    }

    private func goToPage(_ newPage: Int) {
        let pages = pageCount()
        guard newPage >= 0, newPage < pages else { return }
        if springing {
            finishSpring()
        } else if trackingPage {
            stopPager()
        }
        guard newPage != page else { return }
        beginSlide(to: newPage)
    }

    /// Positive means the fingers moved right. Launchpad follows the fingers, not the scroll-direction setting.
    private func fingerDeltaX(_ event: NSEvent) -> CGFloat {
        event.isDirectionInvertedFromDevice ? event.scrollingDeltaX : -event.scrollingDeltaX
    }

    private func turnPage(withFingerDelta delta: CGFloat) {
        if delta < 0 { goToPage(page + 1) } else if delta > 0 { goToPage(page - 1) }
    }

    private func resetScrollGesture() {
        scrollAccumX = 0
        scrollAccumY = 0
        scrollAxisLocked = false
        scrollIsHorizontal = false
    }

    private func noteVelocity(_ dx: CGFloat, time: TimeInterval) {
        let dt = time - lastScrollTime
        lastScrollTime = time
        guard dt > 0.001, dt < 0.08 else {
            if dt >= 0.08 { fingerVelocity = 0 }
            return
        }
        let sample = dx / CGFloat(dt)
        fingerVelocity = min(7000, max(-7000, fingerVelocity * 0.35 + sample * 0.65))
    }

    private func track(delta: CGFloat, time: TimeInterval) {
        let width = max(clip.bounds.width, 1)
        let gained = delta * swipeGain()
        let capped = min(width * 0.42, max(-width * 0.42, gained))
        rawOffset += capped
        noteVelocity(capped, time: time)
        pageOffset = resist(rawOffset)
        trackingPage = true
        syncNeighbor()
    }

    private func settlePage() {
        let width = max(clip.bounds.width, 1)
        let trigger = width * 0.14
        let flick: CGFloat = 1050
        var target: CGFloat = 0
        var commit: Int?
        if fingerVelocity > flick, page > 0 {
            target = width
            commit = page - 1
        } else if fingerVelocity < -flick, page + 1 < pageCount() {
            target = -width
            commit = page + 1
        } else if pageOffset > trigger, page > 0 {
            target = width
            commit = page - 1
        } else if pageOffset < -trigger, page + 1 < pageCount() {
            target = -width
            commit = page + 1
        }
        if let commit, sidePage != commit {
            sidePage = commit
            fill(side, pageIndex: commit)
        }
        let atEdge = commit == nil && ((pageOffset > 0 && page == 0) || (pageOffset < 0 && page + 1 >= pageCount()))
        springVelocity = atEdge ? fingerVelocity * 0.3 : fingerVelocity
        rawOffset = pageOffset
        startSpring(to: target, commit: commit)
    }

    private func handleScroll(_ event: NSEvent) {
        guard dragToken == nil, !folderMotion else { return }
        if openFolderID != nil {
            handleFolderScroll(event)
            return
        }
        let phase = event.phase
        let momentum = event.momentumPhase
        if !momentum.isEmpty { return }

        if phase.contains(.began) {
            if springing {
                pagerTimer?.invalidate()
                pagerTimer = nil
                springing = false
                springCommit = nil
                rawOffset = pageOffset
                springVelocity = 0
                dots.index = page
                dots.needsDisplay = true
            } else {
                rawOffset = 0
                pageOffset = 0
            }
            resetScrollGesture()
            fingerVelocity = 0
            lastScrollTime = event.timestamp
        }

        if phase.contains(.cancelled) {
            springVelocity = 0
            fingerVelocity = 0
            rawOffset = pageOffset
            startSpring(to: 0, commit: nil)
            return
        }

        let live = phase.contains(.began) || phase.contains(.changed) || phase.contains(.ended)
        if live {
            let delta = fingerDeltaX(event)
            scrollAccumX += delta
            scrollAccumY += event.scrollingDeltaY
            if !scrollAxisLocked, max(abs(scrollAccumX), abs(scrollAccumY)) > 8 {
                scrollAxisLocked = true
                scrollIsHorizontal = abs(scrollAccumX) > abs(scrollAccumY) * 0.85
                if scrollIsHorizontal {
                    track(delta: scrollAccumX, time: event.timestamp)
                }
            } else if scrollAxisLocked, scrollIsHorizontal {
                track(delta: delta, time: event.timestamp)
            }
            if phase.contains(.ended) {
                if trackingPage || abs(pageOffset) > 0.5 {
                    settlePage()
                } else {
                    resetScrollGesture()
                }
            }
            return
        }

        if !event.hasPreciseScrollingDeltas {
            let delta = fingerDeltaX(event)
            let horizontal = abs(delta) >= abs(event.scrollingDeltaY) && (abs(delta) > 0.01 || abs(event.deltaX) > 0.01)
            if horizontal {
                turnPage(withFingerDelta: delta != 0 ? delta : -event.deltaX)
            }
        }
    }

    private func setQuery(_ text: String) {
        if text == query, openFolderID == nil { return }
        query = text
        page = 0
        if text.isEmpty {
            selection = keyboardActive ? 0 : nil
        } else {
            openFolderID = nil
            folderOverlay.isHidden = true
            selection = 0
            keyboardActive = true
        }
        refresh(direction: 0)
    }

    private func moveSelection(dx: Int, dy: Int) {
        if openFolderID != nil {
            moveFolderSelection(dx: dx, dy: dy)
            return
        }
        let list = activeList()
        guard !list.isEmpty else { return }
        keyboardActive = true
        guard selection != nil else {
            selection = 0
            page = 0
            refresh(direction: 0)
            return
        }
        var index = selection ?? 0
        if dx != 0 { index += dx }
        if dy != 0 { index += dy * metrics.columns }
        index = max(0, min(list.count - 1, index))
        selection = index
        let newPage = index / metrics.pageSize
        if newPage != page {
            goToPage(newPage)
        } else {
            updateSelectionAppearance()
        }
    }

    private func openSelection() {
        if let folderID = openFolderID {
            let apps = folderApps(folderID)
            let index = folderSelection ?? 0
            guard apps.indices.contains(index) else { return }
            launch(apps[index].id, source: folderCell(appID: apps[index].id))
            return
        }
        let list = activeList()
        let index = selection ?? (query.isEmpty ? nil : 0)
        guard let index, list.indices.contains(index) else { return }
        switch list[index] {
        case .app(let id):
            launch(id, source: cell(token: list[index].token))
        case .folder(let id):
            openFolder(id, source: cell(token: list[index].token))
        }
    }

    private func cell(token: String) -> IconCell? {
        (canvas.subviews.compactMap { $0 as? IconCell }).first { $0.token == token }
    }

    private func backgroundClick() {
        if openFolderID != nil {
            closeFolder()
        } else if !query.isEmpty {
            search.field.stringValue = ""
            setQuery("")
        } else {
            hide(animated: true)
        }
    }

    private func closeFolder() {
        guard openFolderID != nil, !folderClosing else { return }
        if folderTitle.currentEditor() != nil {
            commitFolderTitle()
        }
        stopFolderPager()
        guard allowsAnimation else {
            dismissFolder()
            return
        }
        startFolderCloseAnimation { [weak self] in
            self?.dismissFolder()
        }
    }

    private func dismissFolder() {
        folderMotionTimer?.invalidate()
        folderMotionTimer = nil
        folderMotion = false
        folderClosing = false
        openFolderID = nil
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        folderOverlay.isHidden = true
        folderDim.alphaValue = 1
        for view in [folderPanel, folderNameLabel, folderTitle] as [NSView] {
            view.alphaValue = 1
            view.layer?.transform = CATransform3DIdentity
        }
        CATransaction.commit()
        window.makeFirstResponder(search.field)
        refresh(direction: 0)
    }

    private func folderApps(_ id: String) -> [AppInfo] {
        (library.folder(id)?.apps ?? []).compactMap { library.apps[$0] }
    }

    private func layoutFolder() {
        guard let folderID = openFolderID else {
            folderOverlay.isHidden = true
            return
        }
        guard let folder = library.folder(folderID) else {
            openFolderID = nil
            folderOverlay.isHidden = true
            return
        }
        let animateOpen = openingFolder && allowsAnimation
        if !animateOpen {
            folderOverlay.isHidden = false
        }
        let apps = folderApps(folderID)
        let perPage = 12
        let pages = max(1, Int(ceil(Double(max(apps.count, 1)) / Double(perPage))))
        if folderPage >= pages { folderPage = max(0, pages - 1) }
        if folderTracking || folderSpringing { return }
        let sliceCount = min(perPage, max(0, apps.count - folderPage * perPage))
        let columns = 4
        let rows = 3
        let cellW: CGFloat = 136
        let cellH: CGFloat = 124
        let pad: CGFloat = 28
        let visibleRows = pages > 1 ? rows : min(rows, max(1, Int(ceil(Double(sliceCount) / Double(columns)))))
        let gridW = cellW * CGFloat(columns)
        let gridH = cellH * CGFloat(visibleRows)
        let extra: CGFloat = pages > 1 ? 22 : 0
        let panelSize = CGSize(width: gridW + pad * 2, height: gridH + pad * 2 + extra)
        let panelFrame = CGRect(
            x: (root.bounds.width - panelSize.width) / 2,
            y: (root.bounds.height - panelSize.height) / 2 - 12,
            width: panelSize.width,
            height: panelSize.height
        )
        folderPanel.frame = panelFrame
        folderClip.frame = CGRect(x: pad, y: pad, width: gridW, height: gridH)
        folderGrid.frame = folderClip.bounds
        folderSide.frame = folderClip.bounds
        folderSide.isHidden = true
        folderOffset = 0
        folderRaw = 0
        folderDots.frame = CGRect(x: pad, y: pad + gridH + 2, width: gridW, height: 18)
        folderDots.count = pages
        folderDots.index = folderPage
        folderDots.isHidden = pages <= 1
        if !animateOpen {
            dots.isHidden = true
        }
        let titleH: CGFloat = 46
        let titleFrame = CGRect(
            x: panelFrame.midX - 240,
            y: panelFrame.minY - 18 - titleH,
            width: 480,
            height: titleH
        )
        folderTitle.frame = titleFrame
        folderNameLabel.frame = titleFrame
        if folderTitle.currentEditor() == nil {
            folderTitle.stringValue = folder.name
            folderNameLabel.title = folder.name
            folderTitle.isHidden = true
            folderNameLabel.isHidden = false
        }
        populateFolder(folderGrid, page: folderPage)
        if openingFolder && allowsAnimation {
            startFolderOpenAnimation()
        } else if !folderMotion {
            resetFolderMotion()
            folderOverlay.alphaValue = 1
        }
    }

    private func populateFolder(_ host: NSView, page: Int) {
        guard let folderID = openFolderID else { return }
        let apps = folderApps(folderID)
        let perPage = 12
        let start = page * perPage
        let slice = Array(apps.dropFirst(start).prefix(perPage))
        let columns = 4
        let cellW: CGFloat = 136
        let cellH: CGFloat = 124
        let icon: CGFloat = 72
        host.subviews.forEach { $0.removeFromSuperview() }
        for (index, app) in slice.enumerated() {
            if dragToken == "app:\(app.id)" { continue }
            let entry = Entry(
                token: "app:\(app.id)",
                title: app.name,
                isFolder: false,
                icon: IconCache.shared.icon(for: app.path),
                miniIcons: [],
                appID: app.id,
                folderID: nil
            )
            let cell = IconCell()
            cell.controller = self
            cell.isInFolder = true
            let column = index % columns
            let row = index / columns
            cell.frame = CGRect(x: CGFloat(column) * cellW, y: CGFloat(row) * cellH, width: cellW, height: cellH)
            cell.configure(entry, iconSize: icon)
            cell.selected = keyboardActive && folderSelection == start + index
            host.addSubview(cell)
        }
    }

    private func moveFolderSelection(dx: Int, dy: Int) {
        guard let folderID = openFolderID else { return }
        let apps = folderApps(folderID)
        guard !apps.isEmpty else { return }
        keyboardActive = true
        if folderSelection == nil {
            folderSelection = 0
            updateFolderSelection()
            return
        }
        let columns = 4
        var index = folderSelection ?? 0
        if dx != 0 { index += dx }
        if dy != 0 { index += dy * columns }
        index = max(0, min(apps.count - 1, index))
        folderSelection = index
        let newPage = index / 12
        if newPage != folderPage {
            goToFolderPage(newPage)
        } else {
            updateFolderSelection()
        }
    }

    private func updateFolderSelection() {
        guard let folderID = openFolderID else { return }
        let start = folderPage * 12
        let apps = folderApps(folderID)
        for case let cell as IconCell in folderGrid.subviews {
            let index = apps.firstIndex { $0.id == cell.appID } ?? -1
            cell.selected = keyboardActive && index == folderSelection && index >= start && index < start + 12
        }
    }

    private func folderPageCount() -> Int {
        guard let id = openFolderID else { return 1 }
        return max(1, Int(ceil(Double(max(folderApps(id).count, 1)) / 12.0)))
    }

    private func handleFolderScroll(_ event: NSEvent) {
        let phase = event.phase
        let momentum = event.momentumPhase
        if !momentum.isEmpty { return }
        if phase.contains(.began) {
            if folderSpringing {
                folderPagerTimer?.invalidate()
                folderPagerTimer = nil
                folderSpringing = false
                folderSpringCommit = nil
                folderRaw = folderOffset
                folderSpringVelocity = 0
                folderDots.index = folderPage
                folderDots.needsDisplay = true
            } else {
                folderRaw = 0
                folderOffset = 0
            }
            resetScrollGesture()
            fingerVelocity = 0
            lastScrollTime = event.timestamp
        }
        if phase.contains(.cancelled) {
            folderSpringVelocity = 0
            fingerVelocity = 0
            folderRaw = folderOffset
            startFolderSpring(to: 0, commit: nil)
            return
        }
        let live = phase.contains(.began) || phase.contains(.changed) || phase.contains(.ended)
        if live {
            let delta = fingerDeltaX(event)
            scrollAccumX += delta
            scrollAccumY += event.scrollingDeltaY
            if !scrollAxisLocked, max(abs(scrollAccumX), abs(scrollAccumY)) > 8 {
                scrollAxisLocked = true
                scrollIsHorizontal = abs(scrollAccumX) > abs(scrollAccumY) * 0.85
                if scrollIsHorizontal { trackFolder(delta: scrollAccumX, time: event.timestamp) }
            } else if scrollAxisLocked, scrollIsHorizontal {
                trackFolder(delta: delta, time: event.timestamp)
            }
            if phase.contains(.ended) {
                if folderTracking || abs(folderOffset) > 0.5 {
                    settleFolderPage()
                } else {
                    resetScrollGesture()
                }
            }
            return
        }
        if !event.hasPreciseScrollingDeltas {
            let delta = fingerDeltaX(event)
            let horizontal = abs(delta) >= abs(event.scrollingDeltaY) && (abs(delta) > 0.01 || abs(event.deltaX) > 0.01)
            if horizontal {
                let step = delta != 0 ? delta : -event.deltaX
                if step < 0 { goToFolderPage(folderPage + 1) } else if step > 0 { goToFolderPage(folderPage - 1) }
            }
        }
    }

    private func trackFolder(delta: CGFloat, time: TimeInterval) {
        let width = max(folderClip.bounds.width, 1)
        let gained = delta * max(1.35, width / 720)
        let capped = min(width * 0.42, max(-width * 0.42, gained))
        folderRaw += capped
        noteVelocity(capped, time: time)
        folderOffset = resistedFolderOffset(folderRaw)
        folderTracking = true
        syncFolderNeighbor()
    }

    private func resistedFolderOffset(_ raw: CGFloat) -> CGFloat {
        let width = max(folderClip.bounds.width, 1)
        let lower: CGFloat = folderPage > 0 ? -width : 0
        let upper: CGFloat = folderPage + 1 < folderPageCount() ? width : 0
        if raw < lower { return lower - rubberBand(lower - raw) }
        if raw > upper { return upper + rubberBand(raw - upper) }
        return raw
    }

    private func syncFolderNeighbor() {
        let want: Int?
        if folderOffset < -1, folderPage + 1 < folderPageCount() {
            want = folderPage + 1
        } else if folderOffset > 1, folderPage > 0 {
            want = folderPage - 1
        } else {
            want = nil
        }
        guard want != folderSideIndex else {
            layoutFolderStrip()
            return
        }
        folderSideIndex = want
        if let want {
            populateFolder(folderSide, page: want)
        } else {
            folderSide.subviews.forEach { $0.removeFromSuperview() }
        }
        layoutFolderStrip()
    }

    private func layoutFolderStrip() {
        let bounds = folderClip.bounds
        guard bounds.width > 1, bounds.height > 1 else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        folderGrid.frame = CGRect(x: folderOffset, y: 0, width: bounds.width, height: bounds.height)
        if let folderSideIndex {
            let direction: CGFloat = folderSideIndex > folderPage ? 1 : -1
            folderSide.frame = CGRect(x: folderOffset + direction * bounds.width, y: 0, width: bounds.width, height: bounds.height)
            folderSide.isHidden = false
        } else {
            folderSide.isHidden = true
        }
        CATransaction.commit()
    }

    private func settleFolderPage() {
        let width = max(folderClip.bounds.width, 1)
        let trigger = width * 0.14
        var target: CGFloat = 0
        var commit: Int?
        if fingerVelocity > 1050, folderPage > 0 {
            target = width
            commit = folderPage - 1
        } else if fingerVelocity < -1050, folderPage + 1 < folderPageCount() {
            target = -width
            commit = folderPage + 1
        } else if folderOffset > trigger, folderPage > 0 {
            target = width
            commit = folderPage - 1
        } else if folderOffset < -trigger, folderPage + 1 < folderPageCount() {
            target = -width
            commit = folderPage + 1
        }
        if let commit, folderSideIndex != commit {
            folderSideIndex = commit
            populateFolder(folderSide, page: commit)
        }
        let atEdge = commit == nil && ((folderOffset > 0 && folderPage == 0) || (folderOffset < 0 && folderPage + 1 >= folderPageCount()))
        folderSpringVelocity = atEdge ? fingerVelocity * 0.3 : fingerVelocity
        folderRaw = folderOffset
        startFolderSpring(to: target, commit: commit)
    }

    private func goToFolderPage(_ newPage: Int) {
        let pages = folderPageCount()
        guard newPage >= 0, newPage < pages else { return }
        if folderSpringing {
            finishFolderSpring()
        } else if folderTracking {
            stopFolderPager()
        }
        guard newPage != folderPage else { return }
        guard allowsAnimation else {
            folderPage = newPage
            layoutFolder()
            return
        }
        let width = max(folderClip.bounds.width, 1)
        folderSideIndex = newPage
        populateFolder(folderSide, page: newPage)
        let direction: CGFloat = newPage > folderPage ? -1 : 1
        folderSpringVelocity = direction * width * 1.35
        startFolderSpring(to: direction * width, commit: newPage)
    }

    private func startFolderSpring(to target: CGFloat, commit: Int?) {
        folderSpringTarget = target
        folderSpringCommit = commit
        folderSpringing = true
        folderTracking = false
        folderSpringStarted = Date()
        folderLastTick = folderSpringStarted
        layoutFolderStrip()
        folderDots.index = commit ?? folderPage
        folderDots.needsDisplay = true
        folderPagerTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            self?.stepFolderSpring()
        }
        folderPagerTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stepFolderSpring() {
        guard folderSpringing else { return }
        let now = Date()
        var dt = CGFloat(now.timeIntervalSince(folderLastTick))
        folderLastTick = now
        if dt <= 0 || dt > 1.0 / 30 { dt = 1.0 / 120 }
        let stiffness: CGFloat = 460
        let damping: CGFloat = 43
        folderSpringVelocity += (-stiffness * (folderOffset - folderSpringTarget) - damping * folderSpringVelocity) * dt
        folderOffset += folderSpringVelocity * dt
        layoutFolderStrip()
        let arrived = abs(folderOffset - folderSpringTarget) < 8 && abs(folderSpringVelocity) < 90
        if arrived || now.timeIntervalSince(folderSpringStarted) > 0.7 {
            finishFolderSpring()
        }
    }

    private func finishFolderSpring() {
        folderPagerTimer?.invalidate()
        folderPagerTimer = nil
        let landed = folderSpringCommit
        folderSpringing = false
        folderTracking = false
        folderSpringCommit = nil
        folderSpringVelocity = 0
        fingerVelocity = 0
        folderOffset = 0
        folderRaw = 0
        folderSideIndex = nil
        folderSide.subviews.forEach { $0.removeFromSuperview() }
        folderSide.isHidden = true
        if let landed { folderPage = landed }
        resetScrollGesture()
        layoutFolder()
        updateFolderSelection()
    }

    private func stopFolderPager() {
        folderPagerTimer?.invalidate()
        folderPagerTimer = nil
        folderSpringing = false
        folderTracking = false
        folderSpringCommit = nil
        folderSpringVelocity = 0
        folderOffset = 0
        folderRaw = 0
        folderSideIndex = nil
        folderSide.subviews.forEach { $0.removeFromSuperview() }
        folderSide.isHidden = true
        if folderClip.bounds.width > 1 {
            folderGrid.frame = folderClip.bounds
        }
        resetScrollGesture()
    }

    private func centerAnchor(_ view: NSView) {
        view.wantsLayer = true
        guard let layer = view.layer else { return }
        let desired = CGPoint(x: 0.5, y: 0.5)
        guard layer.anchorPoint != desired else { return }
        let bounds = view.bounds
        let old = layer.anchorPoint
        let dx = (desired.x - old.x) * bounds.width
        let dy = (desired.y - old.y) * bounds.height
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.anchorPoint = desired
        layer.position = CGPoint(x: layer.position.x + dx, y: layer.position.y + dy)
        CATransaction.commit()
    }

    private func folderTransform(_ view: NSView, scale: CGFloat, anchor: CGPoint) -> CATransform3D {
        let center = CGPoint(x: view.frame.midX, y: view.frame.midY)
        let dx = (anchor.x - center.x) * (1 - scale)
        let dy = (anchor.y - center.y) * (1 - scale)
        var transform = CATransform3DIdentity
        transform = CATransform3DTranslate(transform, dx, dy, 0)
        transform = CATransform3DScale(transform, scale, scale, 1)
        return transform
    }

    private func applyFolderPose(_ progress: CGFloat, anchor: CGPoint) {
        let scale = max(0.06, 0.16 + 0.84 * progress)
        let shown = min(1, max(0, progress))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        folderDim.alphaValue = shown
        if shown > 0.2 {
            dots.isHidden = true
        }
        for view in [folderPanel, folderNameLabel] as [NSView] {
            view.alphaValue = shown
            view.layer?.transform = folderTransform(view, scale: scale, anchor: anchor)
        }
        CATransaction.commit()
    }

    private func resetFolderMotion() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        folderDim.alphaValue = 1
        for view in [folderPanel, folderNameLabel, folderTitle] as [NSView] {
            view.alphaValue = 1
            view.layer?.transform = CATransform3DIdentity
        }
        CATransaction.commit()
    }

    private func startFolderOpenAnimation() {
        folderMotionTimer?.invalidate()
        centerAnchor(folderPanel)
        centerAnchor(folderNameLabel)
        folderMotion = true
        applyFolderPose(0, anchor: folderSource)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        folderOverlay.alphaValue = 1
        folderOverlay.isHidden = false
        CATransaction.commit()
        var value: CGFloat = 0
        var velocity: CGFloat = 0
        var last = Date()
        let started = last
        applyFolderPose(value, anchor: folderSource)
        let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let now = Date()
            var dt = CGFloat(now.timeIntervalSince(last))
            last = now
            if dt <= 0 || dt > 1.0 / 30 { dt = 1.0 / 120 }
            let stiffness: CGFloat = 340
            let damping: CGFloat = 28
            velocity += (-stiffness * (value - 1) - damping * velocity) * dt
            value += velocity * dt
            self.applyFolderPose(value, anchor: self.folderSource)
            let arrived = abs(value - 1) < 0.012 && abs(velocity) < 0.08
            if arrived || now.timeIntervalSince(started) > 0.62 {
                timer.invalidate()
                self.folderMotionTimer = nil
                self.folderMotion = false
                self.resetFolderMotion()
            }
        }
        folderMotionTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func startFolderCloseAnimation(completion: @escaping () -> Void) {
        folderMotionTimer?.invalidate()
        centerAnchor(folderPanel)
        centerAnchor(folderNameLabel)
        folderMotion = true
        folderClosing = true
        let started = Date()
        let duration: TimeInterval = 0.26
        let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let t = min(1, Date().timeIntervalSince(started) / duration)
            let progress = 1 - t * t
            self.applyFolderPose(progress, anchor: self.folderSource)
            if t >= 1 {
                timer.invalidate()
                self.folderMotionTimer = nil
                completion()
            }
        }
        folderMotionTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func folderCell(appID: String) -> IconCell? {
        (folderGrid.subviews.compactMap { $0 as? IconCell }).first { $0.appID == appID }
    }

    private func trackClick(_ cell: IconCell) {
        cell.setScale(0.94, animated: true)
        while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if next.type == .leftMouseUp { break }
        }
        cell.setScale(1, animated: true)
        cell.open()
    }

    private func beginDrag(_ cell: IconCell, event: NSEvent) {
        dragToken = cell.token
        dragGrab = cell.convert(event.locationInWindow, from: nil)
        let host: NSView = cell.isInFolder ? folderOverlay : dragLayer
        let frame = host.convert(cell.frame, from: cell.superview)
        cell.removeFromSuperview()
        if host === dragLayer { dragLayer.isHidden = false }
        host.addSubview(cell)
        cell.frame = frame
        cell.setLifted(true)
        lastSlot = nil
        lastFolderSlot = nil
        mergeToken = nil
        folderWillEject = false
        lastDragPoint = host.convert(event.locationInWindow, from: nil)
    }

    private func updateDrag(_ cell: IconCell, event: NSEvent) {
        let host = cell.superview ?? dragLayer
        let point = host.convert(event.locationInWindow, from: nil)
        cell.frame.origin = CGPoint(x: point.x - dragGrab.x, y: point.y - dragGrab.y)
        if cell.isInFolder {
            updateFolderDrag(cell, windowPoint: event.locationInWindow)
            return
        }
        lastDragPoint = point
        let canvasPoint = canvas.convert(event.locationInWindow, from: nil)
        if let target = mergeTarget(at: canvasPoint), canMerge(cell, onto: target) {
            if mergeToken != target.token {
                clearMergeHighlight()
                target.mergeHighlight = true
                mergeToken = target.token
                lastSlot = nil
            }
        } else {
            clearMergeHighlight()
            mergeToken = nil
            if let slot = slot(at: canvasPoint), slot != lastSlot, acceptsReorder(to: slot, point: canvasPoint, token: cell.token) {
                lastSlot = slot
                library.place(token: cell.token, at: slot, saveNow: false)
                let itemPage = pageOf(token: cell.token)
                if let itemPage, itemPage != page {
                    page = itemPage
                    rebuildCanvas()
                } else {
                    syncCanvas(animated: true)
                }
            }
        }
        turnPageIfNeeded(point: point, token: cell.token)
    }

    private func updateFolderDrag(_ cell: IconCell, windowPoint: CGPoint) {
        guard let appID = cell.appID, let folderID = openFolderID else { return }
        let panel = folderPanel.convert(folderPanel.bounds, to: nil).insetBy(dx: -28, dy: -40)
        if !panel.contains(windowPoint) {
            folderWillEject = true
            return
        }
        folderWillEject = false
        let gridPoint = folderGrid.convert(windowPoint, from: nil)
        guard let index = folderSlot(at: gridPoint), index != lastFolderSlot else { return }
        lastFolderSlot = index
        library.moveInsideFolder(appID: appID, folderID: folderID, to: index)
        layoutFolder()
        folderOverlay.addSubview(cell)
    }

    private func endDrag(_ cell: IconCell) {
        let token = cell.token
        let merge = mergeToken
        let inFolder = cell.isInFolder
        let eject = folderWillEject
        let appID = cell.appID
        let folderID = openFolderID
        clearMergeHighlight()
        dragToken = nil
        lastSlot = nil
        lastFolderSlot = nil
        mergeToken = nil
        folderWillEject = false
        cell.setLifted(false)
        cell.removeFromSuperview()
        dragLayer.isHidden = true
        if inFolder {
            if eject, let appID, let folderID {
                library.eject(appID: appID, from: folderID)
            } else {
                library.save()
            }
            refresh(direction: 0)
            return
        }
        if let merge, let target = GridItem(token: merge), case .app(let dragged) = GridItem(token: token) {
            switch target {
            case .app(let other):
                if library.makeFolder(draggedApp: dragged, targetApp: other) == nil { library.save() }
            case .folder(let folderID):
                library.add(appID: dragged, to: folderID)
            }
        } else {
            library.save()
        }
        refresh(direction: 0)
    }

    private func canMerge(_ cell: IconCell, onto target: IconCell) -> Bool {
        guard cell.token != target.token, cell.appID != nil else { return false }
        if target.appID != nil || target.folderID != nil { return true }
        return false
    }

    private func mergeTarget(at point: CGPoint) -> IconCell? {
        for case let cell as IconCell in canvas.subviews {
            if cell.token == dragToken { continue }
            let local = cell.iconBounds.insetBy(dx: -10, dy: -10)
            let icon = local.width > 8
                ? cell.convert(local, to: canvas)
                : cell.convert(cell.bounds.insetBy(dx: cell.bounds.width * 0.28, dy: cell.bounds.height * 0.3), to: canvas)
            if icon.contains(point) { return cell }
        }
        return nil
    }

    private func occupant(at slot: Int) -> IconCell? {
        let list = activeList()
        guard slot >= 0, slot < list.count else { return nil }
        let token = list[slot].token
        if token == dragToken { return nil }
        return canvas.subviews.compactMap { $0 as? IconCell }.first { $0.token == token }
    }

    /// Keep the icon under the pointer where it is, until the pointer has moved past its center.
    private func acceptsReorder(to slot: Int, point: CGPoint, token: String) -> Bool {
        guard let current = activeList().firstIndex(where: { $0.token == token }), slot != current else { return true }
        guard let occupant = occupant(at: slot) else { return true }
        let bounds = occupant.iconBounds
        let center = bounds.width > 2
            ? occupant.convert(CGPoint(x: bounds.midX, y: bounds.midY), to: canvas)
            : occupant.convert(CGPoint(x: occupant.bounds.midX, y: occupant.bounds.midY), to: canvas)
        let columns = metrics.columns
        let passedX = slot % columns == current % columns
            || (slot % columns > current % columns ? point.x >= center.x : point.x <= center.x)
        let passedY = slot / columns == current / columns
            || (slot / columns > current / columns ? point.y >= center.y : point.y <= center.y)
        return passedX && passedY
    }

    private func folderSlot(at point: CGPoint) -> Int? {
        let columns = 4
        let cellW: CGFloat = 136
        let cellH: CGFloat = 124
        guard let folderID = openFolderID else { return nil }
        let count = folderApps(folderID).count
        guard count > 1 else { return nil }
        guard point.x >= 0, point.y >= 0, point.x < folderGrid.bounds.width, point.y < folderGrid.bounds.height else { return nil }
        let column = min(columns - 1, max(0, Int(point.x / cellW)))
        let row = min(2, max(0, Int(point.y / cellH)))
        return min(folderPage * 12 + row * columns + column, count - 1)
    }

    private func clearMergeHighlight() {
        for case let cell as IconCell in canvas.subviews {
            cell.mergeHighlight = false
        }
    }

    private func slot(at point: CGPoint) -> Int? {
        let grid = metrics.grid
        guard grid.contains(point) else { return nil }
        let column = Int((point.x - grid.minX) / metrics.cell.width)
        let row = Int((point.y - grid.minY) / metrics.cell.height)
        guard column >= 0, column < metrics.columns, row >= 0, row < metrics.rows else { return nil }
        return page * metrics.pageSize + row * metrics.columns + column
    }

    private func pageOf(token: String) -> Int? {
        guard let index = activeList().firstIndex(where: { $0.token == token }) else { return nil }
        return index / metrics.pageSize
    }

    private func turnPageIfNeeded(point: CGPoint, token: String) {
        let edge: Int?
        if point.x < 24 { edge = -1 }
        else if point.x > root.bounds.width - 24 { edge = 1 }
        else { edge = nil }
        guard let edge else { edgeStamp = nil; return }
        if edgeStamp == nil { edgeStamp = Date() }
        guard let edgeStamp, Date().timeIntervalSince(edgeStamp) > 0.45 else { return }
        guard Date().timeIntervalSince(lastPageTurn) > 0.55 else { return }
        let next = page + edge
        let listCount = activeList().count
        let pages = max(1, Int(ceil(Double(max(listCount, 1)) / Double(metrics.pageSize))))
        guard next >= 0, next < pages else { return }
        let dest = edge > 0 ? min(listCount - 1, next * metrics.pageSize) : min(listCount - 1, next * metrics.pageSize + metrics.pageSize - 1)
        library.place(token: token, at: max(0, dest), saveNow: false)
        page = next
        lastPageTurn = Date()
        self.edgeStamp = Date()
        lastSlot = nil
        rebuildCanvas()
    }

    private func checkEdgeWhileStationary() {
        guard let token = dragToken else { return }
        turnPageIfNeeded(point: lastDragPoint, token: token)
    }

    private func tuneFieldEditor() {
        guard let editor = search.field.currentEditor() as? NSTextView else { return }
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.insertionPointColor = search.isDark ? .white : .black
    }

    @objc private func statusClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            popStatusMenu()
            return
        }
        toggle()
    }

    @objc private func hotkeyPressed() { toggle() }

    private func popStatusMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let open = menu.addItem(withTitle: "打开启动台", action: #selector(showFromMenu), keyEquivalent: " ")
        open.keyEquivalentModifierMask = [.control, .option]
        open.target = self
        let login = menu.addItem(withTitle: "登录时打开", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = loginEnabled ? .on : .off
        menu.addItem(withTitle: "刷新应用列表", action: #selector(refreshApps), keyEquivalent: "").target = self
        menu.addItem(withTitle: "按类型排列", action: #selector(resetLayout), keyEquivalent: "").target = self
        let hidden = NSMenuItem(title: "已隐藏的应用", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        let hiddenApps = library.hiddenApps()
        if hiddenApps.isEmpty {
            let none = NSMenuItem(title: "没有隐藏的应用", action: nil, keyEquivalent: "")
            none.isEnabled = false
            submenu.addItem(none)
        } else {
            for app in hiddenApps {
                let item = NSMenuItem(title: app.name, action: #selector(unhideApp(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = app.id
                if let icon = IconCache.shared.icon(for: app.path).copy() as? NSImage {
                    icon.size = NSSize(width: 16, height: 16)
                    item.image = icon
                }
                submenu.addItem(item)
            }
        }
        hidden.submenu = submenu
        menu.addItem(hidden)
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出启动台", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q").target = NSApp
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    private var loginEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    @objc private func showFromMenu() { show() }
    @objc private func refreshApps() {
        library.reload { [weak self] in
            guard let self, self.visible else { return }
            self.refresh(direction: 0)
        }
    }
    @objc private func resetLayout() {
        library.resetOrder()
        page = 0
        openFolderID = nil
        if visible { refresh(direction: 0) }
    }
    @objc private func unhideApp(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        library.unhide(appID: id)
        if visible { refresh(direction: 0) }
    }
    @objc private func toggleLogin() {
        guard #available(macOS 13.0, *) else { return }
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "无法设置登录时打开"
            alert.informativeText = "把「启动台」拖进“应用程序”文件夹后再试一次。"
            alert.runModal()
        }
    }

    @objc private func menuOpen(_ sender: NSMenuItem) {
        (sender.representedObject as? IconCell)?.open()
    }
    @objc private func menuReveal(_ sender: NSMenuItem) {
        guard let cell = sender.representedObject as? IconCell, let appID = cell.appID, let app = library.apps[appID] else { return }
        let url = URL(fileURLWithPath: app.path)
        hide(animated: false)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    @objc private func menuHide(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        library.hide(appID: id)
        if let selection, selection > 0 { self.selection = selection - 1 }
        refresh(direction: 0)
    }
    @objc private func menuEject(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: String], let app = info["app"], let folder = info["folder"] else { return }
        library.eject(appID: app, from: folder)
        refresh(direction: 0)
    }
    @objc private func menuRenameFolder(_ sender: NSMenuItem) {
        guard let cell = sender.representedObject as? IconCell, let folderID = cell.folderID else { return }
        openFolder(folderID, source: cell)
        beginFolderRename()
    }

    private func beginFolderRename() {
        guard openFolderID != nil else { return }
        folderTitle.stringValue = folderNameLabel.title
        folderNameLabel.isHidden = true
        folderTitle.isHidden = false
        window.makeFirstResponder(folderTitle)
    }

    @objc private func commitFolderTitle() {
        guard !committingTitle, let id = openFolderID else { return }
        committingTitle = true
        defer { committingTitle = false }
        let name = folderTitle.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            library.renameFolder(id, to: name)
            folderNameLabel.title = name
            cell(token: "folder:\(id)")?.title = name
        }
        folderTitle.isHidden = true
        folderNameLabel.isHidden = false
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field === folderTitle else { return }
        commitFolderTitle()
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        if field === search.field {
            setQuery(field.stringValue)
        }
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        tuneFieldEditor()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if control === folderTitle {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                if let id = openFolderID, let name = library.folder(id)?.name {
                    folderTitle.stringValue = name
                    folderNameLabel.title = name
                }
                folderTitle.isHidden = true
                folderNameLabel.isHidden = false
                window.makeFirstResponder(search.field)
                return true
            }
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                commitFolderTitle()
                window.makeFirstResponder(search.field)
                return true
            }
            return false
        }
        if textView.hasMarkedText() { return false }
        switch commandSelector {
        case #selector(NSResponder.moveLeft(_:)):
            moveSelection(dx: -1, dy: 0)
            return true
        case #selector(NSResponder.moveRight(_:)):
            moveSelection(dx: 1, dy: 0)
            return true
        case #selector(NSResponder.moveUp(_:)):
            moveSelection(dx: 0, dy: -1)
            return true
        case #selector(NSResponder.moveDown(_:)):
            moveSelection(dx: 0, dy: 1)
            return true
        case #selector(NSResponder.insertNewline(_:)):
            openSelection()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            if openFolderID != nil {
                closeFolder()
            } else if !query.isEmpty {
                search.field.stringValue = ""
                setQuery("")
            } else {
                hide(animated: true)
            }
            return true
        case #selector(NSResponder.insertTab(_:)):
            moveSelection(dx: 1, dy: 0)
            return true
        default:
            return false
        }
    }
}
