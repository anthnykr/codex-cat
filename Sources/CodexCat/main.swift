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

struct SpeechBubbleLayout {
    let frame: CGRect
    let textFrame: CGRect
    let path: CGPath
}

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}

@MainActor
final class CatHitView: NSView {
    var onClick: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}

@MainActor
final class CatOverlayView: NSView {
    private let frameCount = 4
    private let goblinPuns = [
        "Goblin up tokens",
        "Prompt goblin",
        "Large Goblin Model",
        "Goblin-assisted coding",
        "Retrieval-Augmented Goblin",
        "Goblin in, goblin out",
        "Fine-tuned goblin",
        "Chain-of-goblin thought",
        "Goblin context window",
        "Halluci-goblin",
        "Autogoblin completion",
        "Goblin gradient descent",
        "Goblin overfitting",
        "Reinforcement Learning from Goblin Feedback",
        "GoblinOps",
        "Goblin-generated content",
        "Goblin prompt injection",
        "Goblin transformer",
        "Goblin embeddings",
        "Goblin-mode activated",
    ]
    private let bubbleLayer = CAShapeLayer()
    private let bubbleTextLayer = CATextLayer()
    private let catLayer = CALayer()
    private var bubbleHideTimer: Timer?
    private var currentPunIndex: Int?
    private var displayTimer: Timer?
    private var lastFrameTime = CACurrentMediaTime()
    private var spriteFrameSize = CGSize(width: 459, height: 345)
    private var spriteImage: CGImage?
    var onCatFrameChanged: ((CGRect) -> Void)?
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
        setupBubble()
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

    func showRandomPun() {
        var nextIndex = Int.random(in: 0..<goblinPuns.count)
        if goblinPuns.count > 1,
           nextIndex == currentPunIndex
        {
            nextIndex = (nextIndex + 1) % goblinPuns.count
        }

        currentPunIndex = nextIndex
        bubbleTextLayer.string = goblinPuns[nextIndex]
        bubbleLayer.isHidden = false
        renderSpeechBubble()

        bubbleHideTimer?.invalidate()
        bubbleHideTimer = Timer.scheduledTimer(
            withTimeInterval: 4,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                self?.bubbleLayer.isHidden = true
            }
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

    private func setupBubble() {
        bubbleLayer.fillColor = NSColor(calibratedWhite: 1, alpha: 0.94).cgColor
        bubbleLayer.strokeColor = NSColor(calibratedWhite: 0.08, alpha: 1).cgColor
        bubbleLayer.lineWidth = 3
        bubbleLayer.isHidden = true
        bubbleLayer.shadowColor = NSColor.black.cgColor
        bubbleLayer.shadowOpacity = 0.18
        bubbleLayer.shadowRadius = 8
        bubbleLayer.shadowOffset = CGSize(width: 0, height: -3)

        bubbleTextLayer.alignmentMode = .center
        bubbleTextLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        bubbleTextLayer.font = NSFont.boldSystemFont(ofSize: 15)
        bubbleTextLayer.fontSize = 15
        bubbleTextLayer.foregroundColor = NSColor(calibratedWhite: 0.08, alpha: 1).cgColor
        bubbleTextLayer.isWrapped = true
        bubbleLayer.addSublayer(bubbleTextLayer)
        layer?.addSublayer(bubbleLayer)
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

        if !bubbleLayer.isHidden {
            renderSpeechBubble()
        }
        onCatFrameChanged?(catLayer.frame.insetBy(dx: -8, dy: -8))

        CATransaction.commit()
    }

    private func renderSpeechBubble() {
        let layout = speechBubbleLayout()

        bubbleLayer.frame = layout.frame
        bubbleLayer.path = layout.path
        bubbleLayer.shadowPath = layout.path
        bubbleTextLayer.frame = layout.textFrame
    }

    private func speechBubbleLayout() -> SpeechBubbleLayout {
        let bubbleSize = CGSize(width: 238, height: 68)
        let tailSize = CGSize(width: 18, height: 12)
        let catFrame = CGRect(
            x: state.position.x,
            y: state.position.y,
            width: state.size.x,
            height: state.size.y
        )
        let bubbleX = min(
            max(catFrame.midX - bubbleSize.width / 2, 8),
            max(bounds.width - bubbleSize.width - 8, 8)
        )
        let canFitAbove = catFrame.maxY + bubbleSize.height + tailSize.height + 10 <= bounds.height
        let bubbleY = canFitAbove
            ? catFrame.maxY + tailSize.height + 8
            : max(catFrame.minY - bubbleSize.height - tailSize.height - 8, 8)
        let bubbleFrame = CGRect(origin: CGPoint(x: bubbleX, y: bubbleY), size: bubbleSize)
        let tailX = min(max(catFrame.midX - bubbleFrame.minX, 24), bubbleSize.width - 24)
        let path = CGMutablePath()
        let bodyFrame = CGRect(origin: .zero, size: bubbleSize)

        path.addRoundedRect(in: bodyFrame, cornerWidth: 15, cornerHeight: 15)
        if canFitAbove {
            path.move(to: CGPoint(x: tailX - tailSize.width / 2, y: 0))
            path.addLine(to: CGPoint(x: tailX, y: -tailSize.height))
            path.addLine(to: CGPoint(x: tailX + tailSize.width / 2, y: 0))
        } else {
            path.move(to: CGPoint(x: tailX - tailSize.width / 2, y: bubbleSize.height))
            path.addLine(to: CGPoint(x: tailX, y: bubbleSize.height + tailSize.height))
            path.addLine(to: CGPoint(x: tailX + tailSize.width / 2, y: bubbleSize.height))
        }
        path.closeSubpath()

        return SpeechBubbleLayout(
            frame: bubbleFrame,
            textFrame: bodyFrame.insetBy(dx: 14, dy: 14),
            path: path
        )
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
    private var clickWindow: NSPanel?
    private var currentCatScreenFrame = CGRect.zero
    private var globalClickMonitor: Any?
    private var overlayWindow: NSWindow?
    private var overlayView: CatOverlayView?
    private var statusItem: NSStatusItem?
    private var pauseMenuItem: NSMenuItem?
    private var alwaysShow = false
    private var isPaused = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        createOverlayWindow()
        createClickWindow()
        createStatusItem()
        startGlobalClickMonitor()
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
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
        }
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    private func createOverlayWindow() {
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 900, height: 600)
        let window = OverlayPanel(
            contentRect: screenFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        let view = CatOverlayView(frame: NSRect(origin: .zero, size: screenFrame.size))
        view.onCatFrameChanged = { [weak self] catFrame in
            self?.updateClickWindowFrame(catFrame: catFrame)
        }
        window.contentView = view
        window.backgroundColor = .clear
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        window.hasShadow = false
        window.hidesOnDeactivate = false
        window.ignoresMouseEvents = true
        window.isOpaque = false
        window.level = .screenSaver
        window.orderFrontRegardless()

        overlayWindow = window
        overlayView = view
    }

    private func createClickWindow() {
        let window = OverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let view = CatHitView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))

        view.onClick = { [weak self] in
            self?.overlayView?.showRandomPun()
        }

        window.contentView = view
        window.backgroundColor = NSColor(calibratedWhite: 0, alpha: 0.001)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        window.hasShadow = false
        window.hidesOnDeactivate = false
        window.ignoresMouseEvents = false
        window.isOpaque = false
        window.level = .screenSaver

        clickWindow = window
    }

    private func startGlobalClickMonitor() {
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            Task { @MainActor in
                self?.handleGlobalClick(event)
            }
        }
    }

    private func handleGlobalClick(_ event: NSEvent) {
        guard overlayWindow?.isVisible == true,
              shouldShowOverlay(for: NSWorkspace.shared.frontmostApplication),
              currentCatScreenFrame.contains(event.locationInWindow)
        else {
            return
        }

        overlayView?.showRandomPun()
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

        if app.processIdentifier == NSRunningApplication.current.processIdentifier {
            return overlayWindow?.isVisible == true
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
            clickWindow?.orderFrontRegardless()
        } else {
            overlayWindow?.orderOut(nil)
            clickWindow?.orderOut(nil)
        }
    }

    private func updateClickWindowFrame(catFrame: CGRect) {
        guard let overlayWindow,
              let clickWindow
        else {
            return
        }

        let screenFrame = CGRect(
            x: overlayWindow.frame.minX + catFrame.minX,
            y: overlayWindow.frame.minY + catFrame.minY,
            width: catFrame.width,
            height: catFrame.height
        )

        clickWindow.setFrame(screenFrame, display: true)
        clickWindow.contentView?.frame = NSRect(origin: .zero, size: screenFrame.size)
        clickWindow.orderFrontRegardless()
        currentCatScreenFrame = screenFrame
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
        overlayView?.frame = NSRect(origin: .zero, size: screenFrame.size)
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
