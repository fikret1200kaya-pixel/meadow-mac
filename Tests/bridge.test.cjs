const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const scheduled = new Map(); let handle = 0, clicked = '', left = false;
const window = {
 requestAnimationFrame: fn => { scheduled.set(++handle,fn); return handle; },
 cancelAnimationFrame: id => scheduled.delete(id),
 dispatchEvent: e => { if(e.type === 'pointerleave') left = true; }
};
const document = {querySelector: selector => ({click: () => {clicked = selector}}), getElementById: () => null,
 body: {classList: {toggle: () => {}}}};
const context = vm.createContext({window,document,Event: class {constructor(type){this.type=type}}, Map});
vm.runInContext(fs.readFileSync(path.join(__dirname,'../Resources/web/mac-bridge.js'),'utf8'),context);
const tick = time => {const jobs = [...scheduled.values()]; scheduled.clear(); jobs.forEach(fn=>fn(time));};
let calls=0;
window.requestAnimationFrame(()=>{calls++; window.requestAnimationFrame(()=>calls++);});
window.meadowMac.pause(true); tick(1); assert.equal(calls,0);
window.meadowMac.pause(false); tick(2); assert.equal(calls,1); tick(3); assert.equal(calls,2);
window.meadowMac.pause(true);
const cancelled = window.requestAnimationFrame(()=>{throw Error('cancelled callback ran')});
window.cancelAnimationFrame(cancelled);
window.meadowMac.pause(false); tick(4);
let cursor;
window.wallpaperBridge.onCursor(p=>cursor=p);
window.meadowMac.cursor(.25,.75); assert.equal(cursor.x,.25); assert.equal(cursor.y,.75);
window.meadowMac.pause(true); window.meadowMac.cursor(.9,.9); assert.equal(cursor.x,.25);
window.meadowMac.leave(); assert.ok(left);
window.meadowMac.scene('wheat'); assert.equal(clicked,'#scenes button[data-scene="wheat"]');
window.meadowMac.scene('bogus'); assert.equal(clicked,'#scenes button[data-scene="wheat"]');
window.meadowMac.mode('night'); assert.equal(clicked,'#modes button[data-mode="night"]');
console.log('PASS: pause/resume, nested frames, cancellation while paused, cursor, leave, scene/mode dispatch');
