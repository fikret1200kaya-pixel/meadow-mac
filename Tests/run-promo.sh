#!/bin/bash
set -euo pipefail
python3 - <<'PY'
from pathlib import Path
s=Path('Sources/main.swift').read_text().split('let app = NSApplication.shared\n')[0]
s=s.replace('override var canBecomeKey:', 'override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }\n    override var canBecomeKey:')
needle='source: "window.meadowOptions=\\(encoded);",'
js="window.__promoClock=0;window.__promoSerial=0;window.__promoQueue=new Map();window.requestAnimationFrame=cb=>{let id=++window.__promoSerial;window.__promoQueue.set(id,cb);return id};window.cancelAnimationFrame=id=>window.__promoQueue.delete(id);performance.now=()=>window.__promoClock;window.__promoStep=dt=>{window.__promoClock+=dt;let cbs=[...window.__promoQueue.values()];window.__promoQueue.clear();cbs.forEach(cb=>cb(window.__promoClock));let c=document.getElementById('c');return {width:c?.width,height:c?.height,frames:window.__frames||0}};"
assert needle in s
s=s.replace(needle,'source: "window.meadowOptions=\\(encoded);'+js+'",')
Path('/tmp/promo-main.swift').write_text(s+Path('Tests/promo-capture.swift').read_text())
PY
cp -R 'dist/Meadow Collection.app' '/tmp/Meadow Promo.app'
python3 - <<'PY4K'
from pathlib import Path
p=Path('/tmp/Meadow Promo.app/Contents/Resources/web/bundle.js')
s=p.read_text();needle='function yM(s){'
assert needle in s
p.write_text(s.replace(needle,'function yM(s){if(window.__promoStep)return;'))
PY4K
xcrun swiftc -swift-version 5 -O -framework Cocoa -framework WebKit -framework CoreGraphics -framework AVFoundation /tmp/promo-main.swift -o '/tmp/Meadow Promo.app/Contents/MacOS/MeadowCollection'
codesign --force --sign - '/tmp/Meadow Promo.app'
'/tmp/Meadow Promo.app/Contents/MacOS/MeadowCollection'
