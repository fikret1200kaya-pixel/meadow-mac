// Compiled together with the production classes for cloud macOS runtime tests.
// Own-window snapshots require no screen-recording or accessibility permission.
final class NativeSmoke {
    let owner: AppDelegate
    let output: URL
    var timer: Timer?
    var busy = false
    var stage = "startup"
    var started = Date()
    var baseline = 0
    var index = 0
    var pauseFrame = 0
    var results: [[String: Any]] = []
    let cases: [(String, String)] = [("meadow","day"),("snow","day"),("lake","day"),("wheat","day"),("sakura","day"),("sakura","golden"),("sakura","night"),("sakura","auto")]
    init(owner: AppDelegate, output: URL) { self.owner = owner; self.output = output }
    func record(_ name: String, _ ok: Bool, _ details: [String: Any] = [:]) {
        var result = details
        result["test"] = name; result["passed"] = ok
        results.append(result)
        print("SMOKE \(ok ? "PASS" : "FAIL") \(name): \(details)")
        fflush(stdout)
        save()
    }
    func save() {
        let report: [String: Any] = ["os": ProcessInfo.processInfo.operatingSystemVersionString,
            "screenCount": NSScreen.screens.count, "tests": results,
            "limitations": "Cloud WKWebView runtime and own-window snapshots; not manual Finder/Spaces/Stage Manager or physical-Mac performance certification."]
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted,.sortedKeys]) {
            try? data.write(to: output.appendingPathComponent("report.json"), options: .atomic)
        }
    }
    func start() {
        try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        guard let surface = owner.surfaces.first else {
            record("GUI session", false, ["reason":"No NSScreen / no wallpaper surface"]); finish(); return
        }
        record("Native app launch", true, ["screenCount":NSScreen.screens.count])
        owner.togglePreview()
        surface.window.setContentSize(NSSize(width: 960, height: 600))
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.poll() }
        started = Date()
    }
    func finish() {
        timer?.invalidate(); save()
        let passed = !results.contains { ($0["passed"] as? Bool) == false }
        try? (passed ? "PASS\n" : "FAIL\n").write(to: output.appendingPathComponent("result.txt"), atomically: true, encoding: .utf8)
        owner.quit()
    }
    func poll() {
        if Date().timeIntervalSince(started) > 90 {
            record("Timeout: \(stage)", false, ["nativeError":owner.lastError]); finish(); return
        }
        guard !busy, let surface = owner.surfaces.first else { return }
        busy = true
        let script = """
        (()=>{const s=window.meadowMac?.status()||{};s.errors=window.__smokeErrors||[];
        const c=document.getElementById('c'); if(c){const g=c.getContext('webgl2')||c.getContext('webgl');
        s.webgl=!!g;s.contextLost=g?g.isContextLost():true;s.width=c.width;s.height=c.height;
        if(g){let e=g.getExtension('WEBGL_debug_renderer_info');s.gpu=e?g.getParameter(e.UNMASKED_RENDERER_WEBGL):g.getParameter(g.RENDERER)}}return s})()
        """
        surface.web.evaluateJavaScript(script) { [weak self] value, error in
            guard let self = self else { return }; self.busy = false
            if let error = error {
                if Date().timeIntervalSince(self.started)>30 { self.record(self.stage,false,["error":error.localizedDescription]); self.finish() }
                return
            }
            guard let state = value as? [String: Any] else { return }
            self.advance(state, surface)
        }
    }
    func advance(_ state: [String: Any], _ surface: Surface) {
        let frames = state["frames"] as? Int ?? 0
        let elapsed = Date().timeIntervalSince(started)
        switch stage {
        case "startup":
            guard frames >= 5 else { return }
            record("WebGL startup", state["webgl"] as? Bool == true && state["contextLost"] as? Bool == false, state)
            beginCase(frames)
        case "scene":
            let test = cases[index]
            guard state["scene"] as? String == test.0, state["mode"] as? String == test.1,
                  frames >= baseline+8, elapsed >= 4 else { return }
            let errors = state["errors"] as? [String] ?? []
            record("Render \(test.0) / \(test.1)", errors.isEmpty && state["contextLost"] as? Bool == false, state)
            stage = "snapshot"; started = Date(); busy = true
            snapshot(surface, name:"\(index+1)-\(test.0)-\(test.1)") { [weak self] in
                guard let self = self else { return }
                self.busy = false
                self.index += 1
                if self.index < self.cases.count { self.beginCase(frames) }
                else {
                    self.owner.togglePause(); self.stage="pause-settle"; self.started=Date()
                }
            }
        case "pause-settle":
            guard elapsed >= 2 else { return }
            pauseFrame=frames; stage="paused"; started=Date()
        case "paused":
            guard elapsed >= 3 else { return }
            record("Pause freezes frame counter", frames == pauseFrame, ["before":pauseFrame,"after":frames])
            baseline=frames; owner.togglePause(); stage="resumed"; started=Date()
        case "resumed":
            guard elapsed >= 3, frames > baseline+3 else { return }
            record("Resume restarts rendering", true, ["before":baseline,"after":frames])
            // Use the app's native desktop route and its real coordinate-forwarding method.
            owner.togglePreview(); owner.updateCursor()
            record("Desktop window configuration", surface.window.ignoresMouseEvents && !surface.window.interactive,
                   ["windowLevel":surface.window.level.rawValue,"desktopLevel":CGWindowLevelForKey(.desktopWindow),
                    "ignoresMouseEvents":surface.window.ignoresMouseEvents])
            baseline=frames; stage="desktop"; started=Date()
        case "desktop":
            guard elapsed >= 5 else { return }
            record("Desktop rendering continues", frames > baseline, ["before":baseline,"after":frames])
            // Trigger the same cursor bridge used by the native desktop sampler.
            surface.run("window.meadowMac.cursor(0.3,0.75);window.meadowMac.cursor(0.7,0.75)")
            baseline=frames; stage="cursor"; started=Date()
        case "cursor":
            guard elapsed >= 3 else { return }
            record("Cursor bridge does not interrupt rendering", frames > baseline && (state["errors"] as? [String] ?? []).isEmpty, state)
            finish()
        default: break
        }
    }
    func beginCase(_ frames: Int) {
        guard let surface=owner.surfaces.first else { finish(); return }
        let test=cases[index]
        surface.run("window.__smokeErrors=[];document.getElementById('err')?.remove();document.body.classList.add('hide-ui')")
        let sceneItem=NSMenuItem();sceneItem.representedObject=test.0;owner.selectScene(sceneItem)
        let modeItem=NSMenuItem();modeItem.representedObject=test.1;owner.selectMode(modeItem)
        baseline=frames;stage="scene";started=Date()
    }
    func snapshot(_ surface: Surface, name: String, completion: @escaping ()->Void) {
        let config=WKSnapshotConfiguration()
        config.rect=surface.web.bounds
        config.snapshotWidth=NSNumber(value:960)
        config.afterScreenUpdates=true
        surface.web.takeSnapshot(with:config) { [weak self] image,error in
            guard let self=self else {return}
            guard let image=image, let tiff=image.tiffRepresentation,
                  let bitmap=NSBitmapImageRep(data:tiff),let png=bitmap.representation(using:.png,properties:[:]) else {
                self.record("Snapshot \(name)",false,["error":error?.localizedDescription ?? "No image"]);completion();return
            }
            var minimum=1.0,maximum=0.0
            // Sample the scene center, avoiding diagnostic text and top controls.
            for y in stride(from:bitmap.pixelsHigh/4,to:bitmap.pixelsHigh*9/10,by:max(1,bitmap.pixelsHigh/50)) {
                for x in stride(from:bitmap.pixelsWide/8,to:bitmap.pixelsWide*7/8,by:max(1,bitmap.pixelsWide/50)) {
                    if let c=bitmap.colorAt(x:x,y:y)?.usingColorSpace(.deviceRGB) {
                        let l=Double((c.redComponent+c.greenComponent+c.blueComponent)/3)
                        minimum=min(minimum,l);maximum=max(maximum,l)
                    }
                }
            }
            try? png.write(to:self.output.appendingPathComponent(name+".png"))
            self.record("Snapshot \(name)", maximum-minimum > 0.025,
                        ["file":name+".png","luminanceRange":maximum-minimum,"width":bitmap.pixelsWide,"height":bitmap.pixelsHigh])
            completion()
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
let outputURL=URL(fileURLWithPath:ProcessInfo.processInfo.environment["MEADOW_TEST_OUTPUT"] ?? FileManager.default.currentDirectoryPath+"/test-results")
let smoke=NativeSmoke(owner:delegate,output:outputURL)
DispatchQueue.main.asyncAfter(deadline:.now()+3) { smoke.start() }
app.run()
