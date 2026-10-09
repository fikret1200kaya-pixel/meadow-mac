#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export MEADOW_TEST_OUTPUT="$PWD/test-results"
mkdir -p "$MEADOW_TEST_OUTPUT"
test_root="$(mktemp -d "$PWD/.meadow-smoke.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT
python3 - "$test_root/main.swift" <<'PY'
from pathlib import Path
import sys
source=Path('Sources/main.swift').read_text()
marker='let app = NSApplication.shared\n'
assert source.count(marker)==1
source=source.split(marker)[0]
# Test-only JS diagnostics; production rendering code remains unchanged.
needle='source: "window.meadowOptions=\\(encoded);",'
extra="window.__smokeErrors=[];window.addEventListener('error',e=>window.__smokeErrors.push(e.message));window.addEventListener('unhandledrejection',e=>window.__smokeErrors.push(String(e.reason)));const oldError=console.error;console.error=(...a)=>{window.__smokeErrors.push(a.map(String).join(' '));oldError.apply(console,a)};"
assert needle in source
source=source.replace(needle, 'source: "window.meadowOptions=\\(encoded);'+extra+'",')
Path(sys.argv[1]).write_text(source+Path('Tests/native-smoke.swift').read_text())
PY
cp -R 'dist/Meadow Collection.app' "$test_root/Meadow Smoke.app"
xcrun swiftc -swift-version 5 -O -framework Cocoa -framework WebKit -framework CoreGraphics \
  "$test_root/main.swift" -o "$test_root/Meadow Smoke.app/Contents/MacOS/MeadowCollection"
codesign --force --sign - "$test_root/Meadow Smoke.app"
python3 - "$test_root/Meadow Smoke.app/Contents/MacOS/MeadowCollection" <<'PY'
import subprocess,sys,os,json
from pathlib import Path
out=Path(os.environ['MEADOW_TEST_OUTPUT'])
with (out/'native.log').open('w') as log:
 try:
  p=subprocess.run([sys.argv[1]],stdout=log,stderr=subprocess.STDOUT,timeout=660)
 except subprocess.TimeoutExpired:
  (out/'timeout.txt').write_text('Native test exceeded 11 minutes. No passing result claimed.\n')
  sys.exit(1)
print((out/'native.log').read_text()[-24000:])
result=out/'result.txt'
if p.returncode !=0 or not result.exists() or result.read_text().strip()!='PASS':
 sys.exit(1)
PY
