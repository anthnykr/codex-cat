import AppKit

struct Vector {
    var x: CGFloat
    var y: CGFloat
}

struct WalkerState {
    var position: Vector
    var velocity: Vector
    var size: Vector
    var speed: CGFloat
}

@MainActor
final class CatOverlayView: NSView {
    private let frameCount = 4
    private let catLayer = CALayer()
    private var displayTimer: Timer?
    private var lastFrameTime = CACurrentMediaTime()
    private var spriteFrameSize = CGSize(width: 459, height: 345)
    private var spriteImage: CGImage?
    private var state = WalkerState(
        position: Vector(x: 80, y: 120),
        velocity: Vector(x: 1, y: 0.42),
        size: Vector(x: 92, y: 69),
        speed: 130
    )

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        setupCat()
        normalizeVelocity()
        startAnimating()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        clampToBounds()
        render()
    }

    func reset() {
        state.position = Vector(x: 80, y: 120)
        normalizeVelocity()
        clampToBounds()
        render()
    }

    func setPaused(_ isPaused: Bool) {
        if isPaused {
            displayTimer?.invalidate()
            displayTimer = nil
        } else if displayTimer == nil {
            lastFrameTime = CACurrentMediaTime()
            startAnimating()
        }
    }

    private func setupCat() {
        spriteImage = loadSpriteImage()
        if let spriteImage {
            spriteFrameSize = CGSize(
                width: spriteImage.width / frameCount,
                height: spriteImage.height
            )
        }

        catLayer.backgroundColor = NSColor.clear.cgColor
        catLayer.contentsGravity = .resizeAspect
        catLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        catLayer.magnificationFilter = .nearest
        catLayer.minificationFilter = .nearest
        layer?.addSublayer(catLayer)
    }

    private func loadSpriteImage() -> CGImage? {
        let resourceURL = Bundle.module.url(forResource: "cat-sprite", withExtension: "png")
            ?? Bundle.main.url(forResource: "cat-sprite", withExtension: "png")
        guard let resourceURL,
              let image = NSImage(contentsOf: resourceURL)
        else {
            return nil
        }

        var proposedRect = CGRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil)
    }

    private func startAnimating() {
        displayTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0 / 60.0,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        let now = CACurrentMediaTime()
        let deltaSeconds = min(now - lastFrameTime, 0.05)
        lastFrameTime = now

        state.position.x += state.velocity.x * deltaSeconds
        state.position.y += state.velocity.y * deltaSeconds
        resolveCollisions()
        render()
    }

    private func normalizeVelocity() {
        let length = hypot(state.velocity.x, state.velocity.y)
        state.velocity = Vector(
            x: state.velocity.x / length * state.speed,
            y: state.velocity.y / length * state.speed
        )
    }

    private func render() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        catLayer.frame = CGRect(
            x: state.position.x,
            y: state.position.y,
            width: state.size.x,
            height: state.size.y
        )
        catLayer.transform = CATransform3DMakeScale(state.velocity.x >= 0 ? 1 : -1, 1, 1)
        catLayer.contents = currentSpriteFrame()

        CATransaction.commit()
    }

    private func currentSpriteFrame() -> CGImage? {
        guard let spriteImage else {
            return nil
        }

        let frameIndex = Int(CACurrentMediaTime() * 8) % frameCount
        let frameRect = CGRect(
            x: CGFloat(frameIndex) * spriteFrameSize.width,
            y: 0,
            width: spriteFrameSize.width,
            height: spriteFrameSize.height
        )

        return spriteImage.cropping(to: frameRect)
    }

    private func clampToBounds() {
        state.position.x = min(max(state.position.x, 0), maxX)
        state.position.y = min(max(state.position.y, 0), maxY)
    }

    private var maxX: CGFloat {
        max(bounds.width - state.size.x, 0)
    }

    private var maxY: CGFloat {
        max(bounds.height - state.size.y, 0)
    }

    private func resolveCollisions() {
        if state.position.x <= 0 {
            state.position.x = 0
            state.velocity.x = abs(state.velocity.x)
        } else if state.position.x >= maxX {
            state.position.x = maxX
            state.velocity.x = -abs(state.velocity.x)
        }

        if state.position.y <= 0 {
            state.position.y = 0
            state.velocity.y = abs(state.velocity.y)
        } else if state.position.y >= maxY {
            state.position.y = maxY
            state.velocity.y = -abs(state.velocity.y)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let codexAppNames = Set(["Codex"])
    private let codexBundleIdentifiers = Set(["com.openai.codex"])
    private var alwaysShowMenuItem: NSMenuItem?
    private var overlayWindow: NSWindow?
    private var overlayView: CatOverlayView?
    private var statusItem: NSStatusItem?
    private var pauseMenuItem: NSMenuItem?
    private var alwaysShow = false
    private var isPaused = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        createOverlayWindow()
        createStatusItem()
        updateOverlayVisibility(for: NSWorkspace.shared.frontmostApplication)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeApplicationChanged(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    private func createOverlayWindow() {
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 900, height: 600)
        let window = NSWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        let view = CatOverlayView(frame: screenFrame)
        window.contentView = view
        window.backgroundColor = .clear
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isOpaque = false
        window.level = .screenSaver
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        overlayWindow = window
        overlayView = view
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Cat"

        let menu = NSMenu()
        pauseMenuItem = NSMenuItem(
            title: "Pause",
            action: #selector(togglePause),
            keyEquivalent: ""
        )

        menu.addItem(pauseMenuItem!)
        alwaysShowMenuItem = NSMenuItem(
            title: "Always Show",
            action: #selector(toggleAlwaysShow),
            keyEquivalent: ""
        )
        alwaysShowMenuItem?.state = .off
        menu.addItem(alwaysShowMenuItem!)
        menu.addItem(
            NSMenuItem(
                title: "Reset Position",
                action: #selector(resetPosition),
                keyEquivalent: ""
            )
        )
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(
                title: "Quit Codex Cat",
                action: #selector(quit),
                keyEquivalent: "q"
            )
        )

        item.menu = menu
        statusItem = item
    }

    private func shouldShowOverlay(for app: NSRunningApplication?) -> Bool {
        if alwaysShow {
            return true
        }

        guard let app else {
            return false
        }

        if let bundleIdentifier = app.bundleIdentifier,
           codexBundleIdentifiers.contains(bundleIdentifier)
        {
            return true
        }

        if let localizedName = app.localizedName,
           codexAppNames.contains(localizedName)
        {
            return true
        }

        return false
    }

    private func updateOverlayVisibility(for app: NSRunningApplication?) {
        let shouldShow = shouldShowOverlay(for: app)

        if shouldShow {
            overlayWindow?.orderFrontRegardless()
        } else {
            overlayWindow?.orderOut(nil)
        }
    }

    @objc private func togglePause() {
        isPaused.toggle()
        overlayView?.setPaused(isPaused)
        pauseMenuItem?.title = isPaused ? "Resume" : "Pause"
    }

    @objc private func toggleAlwaysShow() {
        alwaysShow.toggle()
        alwaysShowMenuItem?.state = alwaysShow ? .on : .off
        updateOverlayVisibility(for: NSWorkspace.shared.frontmostApplication)
    }

    @objc private func resetPosition() {
        overlayView?.reset()
    }

    @objc private func activeApplicationChanged(_ notification: Notification) {
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        updateOverlayVisibility(for: app)
    }

    @objc private func screenParametersChanged() {
        guard let screenFrame = NSScreen.main?.frame else {
            return
        }

        overlayWindow?.setFrame(screenFrame, display: true)
        overlayView?.frame = screenFrame
        overlayView?.reset()
        updateOverlayVisibility(for: NSWorkspace.shared.frontmostApplication)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
