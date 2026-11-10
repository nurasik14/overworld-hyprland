// node run.js <chrome> <profile dir> <page.html> [wait ms]: opens the page in headless Chromium over the DevTools protocol, waits for
// window.__result (set by harness.js finish()) and prints it. Network is blocked by the caller's flags; nothing is shown on screen.
const { spawn } = require("child_process");
const fs = require("fs"), path = require("path");
const [chrome, profile, page, waitMs] = process.argv.slice(2);
const args = ["--headless", "--no-sandbox", "--disable-gpu", "--mute-audio", "--no-first-run", "--disable-extensions",
  "--disable-background-networking", "--disable-sync", "--disable-component-update", "--no-default-browser-check",
  "--host-resolver-rules=MAP * ~NOTFOUND", "--remote-debugging-port=0", "--user-data-dir=" + profile, "--window-size=1280,800", "about:blank"];
const proc = spawn(chrome, args, { stdio: ["ignore", "ignore", "pipe"] });
let done = false;
const quit = (out, code) => { if (done) return; done = true; if (out) process.stdout.write(out + "\n"); try { proc.kill("SIGKILL"); } catch (e) {} process.exit(code); };
setTimeout(() => quit("", 2), parseInt(waitMs || "12000", 10) + 25000);
let buf = "";
proc.stderr.on("data", async d => {
  buf += d;
  const m = buf.match(/DevTools listening on (ws:\/\/\S+)/);
  if (!m || proc.__started) return;
  proc.__started = true;
  const port = new URL(m[1]).port;
  const list = await (await fetch("http://127.0.0.1:" + port + "/json/list")).json();
  const target = list.find(t => t.type === "page");
  const ws = new WebSocket(target.webSocketDebuggerUrl);
  let id = 0; const pending = new Map();
  const send = (method, params) => new Promise(res => { const i = ++id; pending.set(i, res); ws.send(JSON.stringify({ id: i, method, params: params || {} })); });
  ws.onmessage = e => { const msg = JSON.parse(e.data); if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg.result); pending.delete(msg.id); } };
  ws.onopen = async () => {
    await send("Page.enable");
    await send("Page.navigate", { url: "file://" + path.resolve(page) });
    const deadline = Date.now() + (parseInt(waitMs || "12000", 10));
    while (Date.now() < deadline) {
      await new Promise(r => setTimeout(r, 300));
      const r = await send("Runtime.evaluate", { expression: "window.__result || ''", returnByValue: true });
      if (r && r.result && r.result.value) return quit(r.result.value, 0);
    }
    const err = await send("Runtime.evaluate", { expression: "String(window.__error || '')", returnByValue: true });
    quit("", 3);
  };
});
