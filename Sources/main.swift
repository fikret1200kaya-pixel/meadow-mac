import Cocoa
import WebKit
import CoreGraphics

// Build with the macOS SDK; no third-party Swift packages are required.
final class WallpaperWindow: NSWindow {
    var interactive = false
    override var canBecomeKey: Bool { interactive }
    override var canBecomeMain: Bool { interactive }
}

final class Surface: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    let screen: NSScreen
    let window: WallpaperWindow
    let web: WKWebView
    weak var owner: AppDelegate?
    var cursorWasInside = false
    var cursorBusy = false
    var lastCursor = NSPoint(x: -99999, y: -99999)
    var recoveryCount = 0
    var generation = 0
    var healthTimer: Timer?
    var loaded = false

    init(screen: NSScreen, owner: AppDelegate) {
        self.screen = screen
        self.owner = owner
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.websiteDataStore = .nonPersistent()
        web = WKWebView(frame: NSRect(origin: .zero, size: screen.frame.size), configuration: config)
        window = WallpaperWindow(contentRect: screen.frame, styleMask: .borderless,
                                 backing: .buffered, defer: false)
        super.init()
        config.userContentController.add(self, name: "meadow")
        web.navigationDelegate = self
        web.autoresizingMask = [.width, .height]
        window.contentView = web
        window.isReleasedWhenClosed = false
        window.backgroundColor = .black
        window.isOpaque = true
        window.hasShadow = false
        window.animationBehavior = .none
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        desktop()
        load()
    }

    func load(safe: Bool = false) {
        guard let owner = owner, let root = Bundle.main.resourceURL?.appendingPathComponent("web") else { return }
        generation += 1
        let loadGeneration = generation
        loaded = false
        healthTimer?.invalidate()
        let options = "scene=\(owner.scene)&mode=\(owner.mode)&q=\(safe ? "low" : owner.quality)&maxfps=\(owner.fps)&ui=0&wander=\(owner.wander ? 1 : 0)" + (safe ? "&safe=1&post=0" : "")
        let encoded = AppDelegate.json(options)
        web.configuration.userContentController.removeAllUserScripts()
        web.configuration.userContentController.addUserScript(WKUserScript(
            source: "window.meadowOptions=\(encoded);", injectionTime: .atDocumentStart, forMainFrameOnly: true))
        web.loadFileURL(root.appendingPathComponent("index.html"), allowingReadAccessTo: root)
        healthTimer = Timer.scheduledTimer(withTimeInterval: 50, repeats: false) { [weak self] _ in
            guard let self = self, self.generation == loadGeneration, self.owner?.isPaused == false else { return }
            self.web.evaluateJavaScript("window.meadowMac ? window.meadowMac.status() : null") { [weak self] result, _ in
                guard let self = self, self.generation == loadGeneration else { return }
                let frames = (result as? [String: Any])?["frames"] as? Int ?? 0
                if frames < 3 { self.recover("Sahne görüntü oluşturamadı.") }
            }
        }
    }

    func run(_ script: String) { web.evaluateJavaScript(script, completionHandler: nil) }
    func desktop() {
        window.interactive = false
        window.ignoresMouseEvents = true
        window.styleMask = .borderless
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        window.setFrame(screen.frame, display: true)
        window.orderFrontRegardless()
        run("window.meadowMac?.preview(false)")
    }
    func preview() {
        window.interactive = true
        window.ignoresMouseEvents = false
        window.styleMask = [.titled, .resizable, .miniaturizable]
        window.title = "Meadow Collection — Önizleme (menüden masaüstüne dön)"
        window.level = .normal
        let visible = screen.visibleFrame
        let width = min(1100, visible.width * 0.85)
        let height = min(700, visible.height * 0.85)
        window.setFrame(NSRect(x: visible.midX - width/2, y: visible.midY - height/2,
                               width: width, height: height), display: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        run("window.meadowMac?.preview(true)")
    }
    func close() {
        generation += 1
        healthTimer?.invalidate()
        web.stopLoading()
        web.navigationDelegate = nil
        web.configuration.userContentController.removeScriptMessageHandler(forName: "meadow")
        window.orderOut(nil)
        window.close()
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loaded = true
        run("window.meadowMac?.preview(\(window.interactive));window.meadowMac?.pause(\(owner?.isPaused ?? false))")
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { recover("WebKit görüntü işlemi kapandı.") }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        owner?.lastError = error.localizedDescription
        owner?.rebuildMenu()
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // The app only loads its bundled local scenes, never remote pages.
        decisionHandler(navigationAction.request.url?.isFileURL == true ? .allow : .cancel)
    }
    func recover(_ message: String) {
        guard let owner = owner else { return }
        if recoveryCount < 1 {
            recoveryCount += 1
            owner.lastError = message + " Düşük kalitede yeniden deneniyor."
            load(safe: true)
        } else {
            owner.lastError = message + " Menüden Önizleme veya Yeniden Yükle seçin."
        }
        owner.rebuildMenu()
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let state = message.body as? [String: Any], let owner = owner else { return }
        if let error = state["error"] as? String, !error.isEmpty { owner.lastError = error }
        // Only preview interaction may change shared settings; initial page reports do not.
        if window.interactive {
            if let scene = state["scene"] as? String, AppDelegate.sceneIDs.contains(scene), scene != owner.scene {
                owner.scene = scene
                owner.broadcast("window.meadowMac?.scene(\(AppDelegate.json(scene)))", excluding: self)
            }
            if let mode = state["mode"] as? String, AppDelegate.modeIDs.contains(mode), mode != owner.mode {
                owner.mode = mode
                owner.broadcast("window.meadowMac?.mode(\(AppDelegate.json(mode)))", excluding: self)
            }
            owner.persist()
        }
        owner.rebuildMenu()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let sceneIDs = ["meadow", "snow", "lake", "wheat", "sakura"]
    static let modeIDs = ["auto", "day", "golden", "night"]
    let defaults = UserDefaults.standard
    var scene = "meadow", mode = "auto", quality = "medium"
    var fps = 30, wander = false, allScreens = false, userPaused = false, systemPaused = false
    var isPaused: Bool { userPaused || systemPaused }
    var surfaces: [Surface] = []
    var status: NSStatusItem!
    var cursorTimer: Timer?
    var lastError = ""
    var previewing = false
    var activity: NSObjectProtocol?

    static func json(_ value: String) -> String {
        let data = try! JSONSerialization.data(withJSONObject: [value])
        let text = String(data: data, encoding: .utf8)!
        return String(text.dropFirst().dropLast())
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if let v = defaults.string(forKey: "scene"), Self.sceneIDs.contains(v) { scene = v }
        if let v = defaults.string(forKey: "mode"), Self.modeIDs.contains(v) { mode = v }
        if let v = defaults.string(forKey: "quality"), ["low","medium","high","ultra"].contains(v) { quality = v }
        if [30,60].contains(defaults.integer(forKey: "fps")) { fps = defaults.integer(forKey: "fps") }
        wander = defaults.bool(forKey: "wander")
        allScreens = defaults.bool(forKey: "allScreens")
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: "Meadow Collection")
        status.button?.toolTip = "Meadow Collection — Canlı duvar kâğıdı"
        NotificationCenter.default.addObserver(self, selector: #selector(displaysChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let workspace = NSWorkspace.shared.notificationCenter
        for n in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            workspace.addObserver(self, selector: #selector(sleepNow), name: n, object: nil)
        }
        for n in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            workspace.addObserver(self, selector: #selector(wakeNow), name: n, object: nil)
        }
        createSurfaces()
        cursorTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in self?.updateCursor() }
        updateActivity()
        rebuildMenu()
    }
    func persist() {
        defaults.set(scene, forKey: "scene"); defaults.set(mode, forKey: "mode")
        defaults.set(quality, forKey: "quality"); defaults.set(fps, forKey: "fps")
        defaults.set(wander, forKey: "wander"); defaults.set(allScreens, forKey: "allScreens")
    }
    func createSurfaces() {
        surfaces.forEach { $0.close() }; surfaces.removeAll()
        previewing = false
        // NSScreen.screens.first is the display with the menu bar, not the focused window's screen.
        let screens = allScreens ? NSScreen.screens : Array(NSScreen.screens.prefix(1))
        surfaces = screens.map { Surface(screen: $0, owner: self) }
    }
    func broadcast(_ script: String, excluding: Surface? = nil) {
        surfaces.filter { $0 !== excluding }.forEach { $0.run(script) }
    }
    func updateCursor() {
        guard !isPaused else { return }
        let point = NSEvent.mouseLocation
        for surface in surfaces where !surface.window.interactive && surface.loaded {
            let rect = surface.screen.frame
            let inside = NSPointInRect(point, rect)
            if inside {
                if surface.cursorBusy || (surface.cursorWasInside && surface.lastCursor == point) { continue }
                surface.lastCursor = point
                surface.cursorWasInside = true
                surface.cursorBusy = true
                let x = (point.x - rect.minX) / rect.width
                let y = 1 - (point.y - rect.minY) / rect.height
                surface.web.evaluateJavaScript("window.meadowMac?.cursor(\(x),\(y))") { [weak surface] _, _ in surface?.cursorBusy = false }
            } else if surface.cursorWasInside {
                surface.cursorWasInside = false
                surface.run("window.meadowMac?.leave()")
            }
        }
    }
    func updateActivity() {
        if isPaused {
            if let a = activity { ProcessInfo.processInfo.endActivity(a); activity = nil }
        } else if activity == nil {
            // Keep desktop rendering active without preventing idle display/system sleep.
            activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiatedAllowingIdleSystemSleep], reason: "Render live wallpaper")
        }
    }
    func syncPause() {
        broadcast("window.meadowMac?.pause(\(isPaused))")
        updateActivity(); rebuildMenu()
    }
    func submenu(_ title: String, entries: [(String,String)], selected: String, action: Selector, parent: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let menu = NSMenu(title: title)
        for (label, value) in entries {
            let child = NSMenuItem(title: label, action: action, keyEquivalent: "")
            child.target = self; child.representedObject = value
            child.state = value == selected ? .on : .off
            menu.addItem(child)
        }
        item.submenu = menu; parent.addItem(item)
    }
    @discardableResult func item(_ title: String, _ action: Selector, to menu: NSMenu, checked: Bool = false) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self; item.state = checked ? .on : .off; menu.addItem(item); return item
    }
    func rebuildMenu() {
        guard status != nil else { return }
        let menu = NSMenu()
        let heading = NSMenuItem(title: "Meadow Collection • Mac", action: nil, keyEquivalent: "")
        heading.isEnabled = false; menu.addItem(heading)
        submenu("Sahne", entries: [("Çimen Tepesi","meadow"),("Karlı Dağ Evi","snow"),("Göl Evi","lake"),("Buğday Tarlası","wheat"),("Sakura Gölü","sakura")], selected: scene, action: #selector(selectScene(_:)), parent: menu)
        submenu("Günün saati", entries: [("Otomatik • bilgisayar saati","auto"),("Gündüz","day"),("Altın saat","golden"),("Gece","night")], selected: mode, action: #selector(selectMode(_:)), parent: menu)
        submenu("Kalite", entries: [("Düşük","low"),("Dengeli","medium"),("Yüksek","high"),("Ultra","ultra")], selected: quality, action: #selector(selectQuality(_:)), parent: menu)
        submenu("Kare hızı", entries: [("30 FPS • daha az güç","30"),("60 FPS • daha akıcı","60")], selected: String(fps), action: #selector(selectFPS(_:)), parent: menu)
        item("Boştayken otomatik etkileşim", #selector(toggleWander), to: menu, checked: wander)
        item("Tüm ekranlarda göster", #selector(toggleScreens), to: menu, checked: allScreens)
        menu.addItem(.separator())
        item(previewing ? "Masaüstüne dön" : "Önizleme / tıklayarak etkileşim", #selector(togglePreview), to: menu)
        item(userPaused ? "Animasyonu sürdür" : "Animasyonu duraklat", #selector(togglePause), to: menu)
        item("Yeniden yükle", #selector(reload), to: menu)
        if !lastError.isEmpty { item("Hata ayrıntıları…", #selector(showError), to: menu) }
        menu.addItem(.separator())
        item("Kullanım bilgisi…", #selector(about), to: menu)
        item("Çıkış", #selector(quit), to: menu).keyEquivalent = "q"
        status.menu = menu
    }
    @objc func selectScene(_ item: NSMenuItem) {
        guard let value = item.representedObject as? String else { return }
        scene = value; persist(); broadcast("window.meadowMac?.scene(\(Self.json(value)))"); rebuildMenu()
    }
    @objc func selectMode(_ item: NSMenuItem) {
        guard let value = item.representedObject as? String else { return }
        mode = value; persist(); broadcast("window.meadowMac?.mode(\(Self.json(value)))"); rebuildMenu()
    }
    @objc func selectQuality(_ item: NSMenuItem) { quality = item.representedObject as! String; persist(); reload() }
    @objc func selectFPS(_ item: NSMenuItem) { fps = Int(item.representedObject as! String)!; persist(); reload() }
    @objc func toggleWander() { wander.toggle(); persist(); reload() }
    @objc func toggleScreens() { allScreens.toggle(); persist(); createSurfaces(); rebuildMenu() }
    @objc func togglePause() { userPaused.toggle(); syncPause() }
    @objc func togglePreview() {
        previewing.toggle()
        if previewing { surfaces.first?.preview() } else { surfaces.first?.desktop() }
        rebuildMenu()
    }
    @objc func reload() {
        lastError = ""
        for surface in surfaces { surface.recoveryCount = 0; surface.load() }
        rebuildMenu()
    }
    @objc func displaysChanged() { createSurfaces(); rebuildMenu() }
    @objc func sleepNow() { systemPaused = true; syncPause() }
    @objc func wakeNow() { systemPaused = false; syncPause() }
    @objc func showError() { alert("Görüntüleme bilgisi", lastError) }
    @objc func about() {
        alert("Meadow Collection — Mac deneme sürümü", "Üst menüdeki yaprak simgesi ile sahne, saat, kalite ve FPS seçilir.\n\nMasaüstü modunda simgeler ve tıklamalar Finder'a aittir; fare hareketi sahneyi etkiler. Tıklama efektleri için Önizleme'yi açın.\n\nVarsayılan: Dengeli kalite, 30 FPS, ana ekran. Çıkış yapınca normal duvar kâğıdı geri görünür.\n\nOturum açılışında çalıştırmak için uygulamayı macOS Oturum Açma Öğeleri'ne ekleyebilirsiniz.\n\nBu uyarlama gerçek bir Mac üzerinde henüz doğrulanmadı.")
    }
    func alert(_ title: String, _ text: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert(); alert.messageText = title; alert.informativeText = text
        alert.addButton(withTitle: "Tamam"); alert.runModal()
    }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) {
        cursorTimer?.invalidate(); surfaces.forEach { $0.close() }
        if let a = activity { ProcessInfo.processInfo.endActivity(a) }
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
