// Full-page captures over DevTools: node capture.mjs <url> <outdir>
import { spawn } from 'node:child_process'
import { writeFileSync } from 'node:fs'
const [url, out] = process.argv.slice(2)
const chrome = spawn('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  ['--headless=new', '--remote-debugging-port=9333', '--hide-scrollbars', '--force-prefers-reduced-motion', '--user-data-dir=' + out + '/.chrome', 'about:blank'], { stdio: 'ignore' })
const sleep = (ms) => new Promise((r) => setTimeout(r, ms))
let target
for (let i = 0; i < 50 && !target; i++) { await sleep(200); try { target = (await (await fetch('http://127.0.0.1:9333/json')).json()).find((t) => t.type === 'page') } catch {} }
const ws = new WebSocket(target.webSocketDebuggerUrl)
await new Promise((r) => (ws.onopen = r))
let id = 0; const pending = {}
ws.onmessage = ({ data }) => { const m = JSON.parse(data); if (m.id && pending[m.id]) { pending[m.id](m.result); delete pending[m.id] } }
const send = (method, params = {}) => new Promise((r) => { pending[++id] = r; ws.send(JSON.stringify({ id, method, params })) })
for (const [w, h, mobile] of [[2560, 1440, false], [1920, 1080, false], [1440, 900, false], [390, 844, true]]) {
  await send('Emulation.setDeviceMetricsOverride', { width: w, height: h, deviceScaleFactor: 1, mobile })
  await send('Page.navigate', { url }); await sleep(3500)
  const { cssContentSize } = await send('Page.getLayoutMetrics')
  const full = Math.ceil(cssContentSize.height)
  const name = { 2560: 'desktop-2560', 1920: 'desktop-1920', 1440: 'desktop', 390: 'mobile' }[w]
  // Scroll through like a visitor so reveals fire, keeping the real viewport so vh layouts hold.
  for (let y = 0, n = 0; y < full; y += h, n++) {
    await send('Runtime.evaluate', { expression: `window.scrollTo(0, ${y})` }); await sleep(700)
    const top = (await send('Runtime.evaluate', { expression: 'window.scrollY', returnByValue: true })).result.value
    const shot = await send('Page.captureScreenshot', { format: 'png' })
    writeFileSync(`${out}/.tiles-${name}-${String(n).padStart(3, '0')}-${top}.png`, Buffer.from(shot.data, 'base64'))
  }
  console.log(name, w, 'x', full)
}
chrome.kill(); process.exit(0)
