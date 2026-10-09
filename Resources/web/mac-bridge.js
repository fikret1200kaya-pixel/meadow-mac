/* macOS host bridge. No network access or external dependencies. */
(() => {
  'use strict';
  const nativeRAF = window.requestAnimationFrame.bind(window);
  const nativeCancel = window.cancelAnimationFrame.bind(window);
  let paused = false, serial = 0;
  const pending = new Map();
  const schedule = (id, entry) => {
    entry.handle = nativeRAF(time => {
      entry.handle = null;
      if (paused || !pending.has(id)) return;
      pending.delete(id);
      entry.callback(time);
    });
  };
  window.requestAnimationFrame = callback => {
    const id = ++serial, entry = { callback, handle: null };
    pending.set(id, entry);
    if (!paused) schedule(id, entry);
    return id;
  };
  window.cancelAnimationFrame = id => {
    const entry = pending.get(id);
    if (entry?.handle != null) nativeCancel(entry.handle);
    pending.delete(id);
  };
  let cursorListener = null;
  window.wallpaperBridge = { onCursor: callback => { cursorListener = callback; } };
  window.meadowMac = {
    pause(value) {
      if (paused === !!value) return;
      paused = !!value;
      for (const [id, entry] of pending) {
        if (paused) {
          if (entry.handle != null) nativeCancel(entry.handle);
          entry.handle = null;
        } else schedule(id, entry);
      }
    },
    cursor(x, y) {
      if (!paused && cursorListener) cursorListener({ x, y });
    },
    leave() { window.dispatchEvent(new Event('pointerleave')); },
    scene(id) {
      if (!['meadow','snow','lake','wheat','sakura'].includes(id)) return;
      document.querySelector(`#scenes button[data-scene="${id}"]`)?.click();
    },
    mode(id) {
      if (!['auto','day','golden','night'].includes(id)) return;
      document.querySelector(`#modes button[data-mode="${id}"]`)?.click();
    },
    preview(value) {
      document.body.classList.toggle('mac-desktop', !value);
      document.body.classList.toggle('hide-ui', !value);
    },
    status() {
      return { ready: !!window.__ready, frames: window.__frames || 0,
        error: document.getElementById('err')?.textContent || '',
        scene: document.querySelector('#scenes button.on')?.dataset.scene,
        mode: document.querySelector('#modes button.on')?.dataset.mode,
        paused };
    }
  };
  if (window.webkit?.messageHandlers?.meadow) {
    document.body.classList.add('mac-desktop');
    const style = document.createElement('style');
    style.textContent = 'body.mac-desktop > div:not(#err){display:none!important}';
    document.head.appendChild(style);
    const report = () => window.webkit.messageHandlers.meadow.postMessage(window.meadowMac.status());
    document.addEventListener('click', () => setTimeout(report, 0));
    setTimeout(report, 1500);
    setTimeout(report, 12000);
  }
})();
