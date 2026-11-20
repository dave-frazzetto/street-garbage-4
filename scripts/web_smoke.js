// Web build smoke test through the Chrome DevTools Protocol (no npm packages needed, Node 22+).
// Loads the served build, taps START, drives both touch sticks with real touch events, saves screenshots
// to tests/output/ and fails on console errors.
// Usage: node scripts/serve_web.js &  then  node scripts/web_smoke.js [chrome.exe path]
const { spawn } = require("child_process");
const fs = require("fs");
const path = require("path");
const os = require("os");

const chrome = process.argv[2] || "C:/Program Files/Google/Chrome/Application/chrome.exe";
const url = process.argv[3] || "http://localhost:8060/";
const outDir = path.join(__dirname, "..", "tests", "output");
fs.mkdirSync(outDir, { recursive: true });
const port = 9333;
const profile = fs.mkdtempSync(path.join(os.tmpdir(), "sg4cdp-"));
const proc = spawn(chrome, [
  "--headless=new", `--remote-debugging-port=${port}`, `--user-data-dir=${profile}`,
  "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--window-size=1280,720", "about:blank",
], { stdio: "ignore" });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let ws, nextId = 1;
const pending = new Map();
const errors = [];
function send(method, params = {}) {
  const id = nextId++;
  ws.send(JSON.stringify({ id, method, params }));
  return new Promise((resolve, reject) => pending.set(id, { resolve, reject }));
}
async function shot(name) {
  const r = await send("Page.captureScreenshot", { format: "png" });
  fs.writeFileSync(path.join(outDir, name), Buffer.from(r.data, "base64"));
  console.log("saved", name);
}
async function touch(type, points) {
  await send("Input.dispatchTouchEvent", { type, touchPoints: points });
}

(async () => {
  let targets;
  for (let i = 0; i < 50; i++) {
    try { targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json(); break; } catch { await sleep(200); }
  }
  const page = targets.find((t) => t.type === "page");
  ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((r) => (ws.onopen = r));
  ws.onmessage = (m) => {
    const msg = JSON.parse(m.data);
    if (msg.id && pending.has(msg.id)) { pending.get(msg.id).resolve(msg.result || {}); pending.delete(msg.id); }
    if (msg.method === "Runtime.consoleAPICalled" && msg.params.type === "error") {
      errors.push(msg.params.args.map((a) => a.value ?? a.description).join(" "));
    }
    if (msg.method === "Runtime.exceptionThrown") errors.push(msg.params.exceptionDetails.text);
  };
  await send("Runtime.enable");
  await send("Page.enable");
  await send("Emulation.setDeviceMetricsOverride", { width: 1280, height: 720, deviceScaleFactor: 1, mobile: true });
  await send("Emulation.setTouchEmulationEnabled", { enabled: true, maxTouchPoints: 5 });
  await send("Page.navigate", { url });
  await sleep(15000);
  await shot("web_1_title.png");
  // Tap START (centre-bottom of the title layout).
  await touch("touchStart", [{ x: 640, y: 600, id: 0 }]);
  await touch("touchEnd", []);
  await sleep(1500);
  await shot("web_2_game.png");
  // Left stick move right + right stick aim down-right, held together.
  await touch("touchStart", [{ x: 250, y: 550, id: 1 }]);
  await touch("touchStart", [{ x: 250, y: 550, id: 1 }, { x: 1000, y: 450, id: 2 }]);
  for (let i = 0; i < 20; i++) {
    await touch("touchMove", [{ x: 250 + i * 6, y: 550, id: 1 }, { x: 1000 + i * 4, y: 450 + i * 5, id: 2 }]);
    await sleep(60);
  }
  await sleep(800);
  await shot("web_3_touch_sticks.png");
  await touch("touchEnd", []);
  const real = errors.filter((e) => !/favicon|AudioContext/i.test(e));
  console.log(real.length ? "CONSOLE ERRORS:\n" + real.join("\n") : "no console errors");
  console.log(real.length ? "DONE: web smoke FAILED" : "DONE: web smoke passed");
  ws.close();
  proc.kill();
  process.exit(real.length ? 1 : 0);
})().catch((e) => { console.error(e); proc.kill(); process.exit(1); });
