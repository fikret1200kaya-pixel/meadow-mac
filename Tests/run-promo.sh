#!/bin/bash
set -euo pipefail
python3 - <<'PY'
from pathlib import Path
s=Path('Sources/main.swift').read_text().split('let app = NSApplication.shared\n')[0]
Path('/tmp/promo-main.swift').write_text(s+Path('Tests/promo-capture.swift').read_text())
PY
cp -R 'dist/Meadow Collection.app' '/tmp/Meadow Promo.app'
xcrun swiftc -swift-version 5 -O -framework Cocoa -framework WebKit -framework CoreGraphics -framework AVFoundation /tmp/promo-main.swift -o '/tmp/Meadow Promo.app/Contents/MacOS/MeadowCollection'
codesign --force --sign - '/tmp/Meadow Promo.app'
'/tmp/Meadow Promo.app/Contents/MacOS/MeadowCollection'
