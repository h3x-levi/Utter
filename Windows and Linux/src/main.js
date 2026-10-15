const {
  app, BrowserWindow, Tray, Menu, ipcMain, clipboard, ClipboardItem, globalShortcut, nativeTheme, nativeImage,
  screen, session, shell, dialog, desktopCapturer, crashReporter,
} = require('electron')
const path = require('node:path')
const fs = require('node:fs')
const os = require('node:os')
const net = require('node:net')
const { spawn } = require('node:child_process')
const { randomUUID } = require('node:crypto')
const text = require('./text')
const winHelper = require('./win-helper')
const companion = require('./companion')

const WIN = process.platform === 'win32'
const LINUX = process.platform === 'linux'

// Hold-to-talk and the pill need X11, so a Wayland session runs Utter through XWayland.
if (LINUX && process.env.WAYLAND_DISPLAY && !process.argv.includes('--ozone-platform=x11')) {
  app.relaunch({ execPath: process.env.APPIMAGE || process.execPath, args: [...process.argv.slice(1), '--ozone-platform=x11'] })
  app.exit(0)
}
if (!app.requestSingleInstanceLock()) app.exit(0)

crashReporter.start({ uploadToServer: false })
const dataDir = process.env.UTTER_DATA_DIR || app.getPath('userData')
fs.mkdirSync(dataDir, { recursive: true, mode: 0o700 })
app.setPath('sessionData', path.join(dataDir, 'Session'))

const resources = app.isPackaged ? process.resourcesPath : path.join(__dirname, '..')
const bundledModel = app.isPackaged ? path.join(resources, 'models', 'ggml-small.en-q5_1.bin') : path.join(resources, '..', 'Models', 'ggml-small.en-q5_1.bin')
const vadModel = app.isPackaged ? path.join(resources, 'models', 'ggml-silero-v6.2.0.bin') : path.join(resources, '..', 'Models', 'ggml-silero-v6.2.0.bin')
const vadArgs = fs.existsSync(vadModel) ? ['--vad', '-vm', vadModel, '-vp', '200'] : []
const serverDir = app.isPackaged ? path.join(resources, 'whisper') : path.join(resources, 'vendor', WIN ? 'win' : 'linux')
const serverBin = path.join(serverDir, WIN ? 'whisper-server.exe' : 'whisper-server')
const asset = (name) => path.join(__dirname, '..', 'assets', name)
const sleep = (ms) => new Promise((r) => setTimeout(r, ms))
const WINDOW = 30 * text.RATE

// ---------- Files (same names and shapes as the Mac app) ----------

const file = (name) => path.join(dataDir, name)
let resetting = false

function readJSON(name, fallback) {
  try {
    return JSON.parse(fs.readFileSync(file(name), 'utf8'))
  } catch (error) {
    if (error.code !== 'ENOENT') fs.renameSync(file(name), file(`${path.parse(name).name}-unreadable-${Math.floor(Date.now() / 1000)}.json`))
    return fallback
  }
}

function writeJSON(name, value, backup) {
  if (resetting) return
  const data = JSON.stringify(value, null, 2)
  if (backup) {
    try {
      const old = fs.readFileSync(file(name))
      if (!old.equals(Buffer.from(data))) fs.writeFileSync(file(backup), old, { mode: 0o600 })
    } catch {}
  }
  fs.writeFileSync(file(name + '.tmp'), data, { mode: 0o600 })
  fs.renameSync(file(name + '.tmp'), file(name))
}

const pending = {}
function saveLater(name, ms) {
  clearTimeout(pending[name]?.timer)
  pending[name] = { timer: setTimeout(() => saveNow(name), ms) }
}
function saveNow(name) {
  clearTimeout(pending[name]?.timer)
  delete pending[name]
  if (name === 'history') writeJSON('history.json', history)
  if (name === 'notes') writeJSON('notes.json', notes, 'notes.previous.json')
  if (name === 'userdata') writeJSON('userdata.json', ud)
}
const flushSaves = () => Object.keys(pending).forEach(saveNow)

const DEFAULTS = {
  words: [], snippets: [], language: 'english', voiceCommands: true, spokenPunctuation: false,
  hotkeyId: 'ctrlWin', hotkeyName: WIN ? 'Ctrl + Windows' : 'Ctrl + Super', doubleTapHotkeyForHandsFree: true, microphoneUID: '',
  keepHistory: true, speechBiasEnabled: true, appTheme: 'system', alwaysShowPill: true, soundsEnabled: true,
  captureAppendsToOpenNote: true, openAtLogin: false, companionDictationGoal: 500, offerToTranscribeCalls: false,
  muteMusicWhileDictating: false, livePreviewEnabled: false, hasCompletedOnboarding: false, selectedSpeechModel: 'small',
}
const SETTINGS = ['appTheme', 'alwaysShowPill', 'openAtLogin', 'soundsEnabled', 'captureAppendsToOpenNote', 'spokenPunctuation',
  'voiceCommands', 'speechBiasEnabled', 'keepHistory', 'hotkeyId', 'hotkeyName', 'doubleTapHotkeyForHandsFree', 'microphoneUID',
  'companionDictationGoal', 'offerToTranscribeCalls', 'muteMusicWhileDictating', 'livePreviewEnabled', 'hasCompletedOnboarding',
  'selectedSpeechModel']

let ud, history, notes
function loadData() {
  ud = { ...DEFAULTS, ...readJSON('userdata.json', {}) }
  if (!['system', 'light', 'dark'].includes(ud.appTheme)) ud.appTheme = 'system'
  const h = readJSON('history.json', [])
  history = Array.isArray(h) ? h.filter((e) => e && text.isUsable(e.text)) : []
  const n = readJSON('notes.json', [])
  notes = Array.isArray(n) ? n.sort(byModified) : []
}
const byModified = (a, b) => Date.parse(b.modified) - Date.parse(a.modified)
const isoSeconds = (d = new Date()) => d.toISOString().replace(/\.\d{3}Z$/, 'Z')
const today = (d = new Date()) => d.getFullYear() * 10000 + (d.getMonth() + 1) * 100 + d.getDate()
const todayWords = () => (ud.companionProgress?.day === today() ? ud.companionProgress.dictationWords || 0 : 0)

function addWords(count) {
  const p = ud.companionProgress?.day === today() ? ud.companionProgress
    : { ...ud.companionProgress, day: today(), hydration: 0, stretches: 0, focusBlocks: 0, dictationWords: 0 }
  p.dictationWords = (p.dictationWords || 0) + count
  p.dictations = (p.dictations || 0) + 1
  ud.companionProgress = p
  saveLater('userdata', 300)
}

// ---------- Notes ----------

const findNote = (id) => notes.find((n) => n.id === id)
const SPEAKERS = { you: 'You', others: 'Others' }
let openNoteId = null

function createNote(body = '', source = 'typed') {
  const now = new Date().toISOString()
  const note = { id: randomUUID().toUpperCase(), title: text.derivedTitle(body), body, created: now, modified: now, tags: [], source, titleIsCustom: false }
  notes.unshift(note)
  saveNow('notes')
  changed()
  return note
}

function editNote(note, patch) {
  if (patch.body !== undefined) note.body = patch.body
  if (patch.title !== undefined) {
    note.title = patch.title
    note.titleIsCustom = patch.titleIsCustom ?? Boolean(patch.title.trim())
  }
  if (!note.titleIsCustom) note.title = text.derivedTitle(note.body)
  note.modified = new Date().toISOString()
  notes.sort(byModified)
}

function appendToNote(note, addition) {
  const sep = !note.body ? '' : note.body.endsWith('\n') ? '\n' : '\n\n'
  editNote(note, { body: note.body + sep + addition })
  saveNow('notes')
  changed()
}

// ---------- Speech models (the same catalog and checksums as the Mac app) ----------

const MODELS = [
  { id: 'base', name: 'Base', file: 'ggml-base.en-q5_1.bin', sizeMB: 57, sha256: '4baf70dd0d7c4247ba2b81fafd9c01005ac77c2f9ef064e00dcf195d0e2fdd2f',
    summary: 'Fastest and smallest. Fine for everyday notes, weaker on unusual names.' },
  { id: 'small', name: 'Small', file: 'ggml-small.en-q5_1.bin', sizeMB: 181, bundled: true, sha256: 'bfdff4894dcb76bbf647d56263ea2a96645423f1669176f4844a1bf8e478ad30',
    summary: 'Fast and light, English-only. A good default on any computer, including 8 GB machines.' },
  { id: 'medium', name: 'Medium', file: 'ggml-medium.en-q5_0.bin', sizeMB: 514, sha256: '76733e26ad8fe1c7a5bf7531a9d41917b2adc0f20f2e4f5531688a8c6cd88eb0',
    summary: 'Most accurate on technical terms and unusual names, but English-only, so it can struggle with strong or non-native accents. 10\u00D7 faster than real time.' },
  { id: 'turbo', name: 'Large Turbo', file: 'ggml-large-v3-turbo-q5_0.bin', sizeMB: 547, sha256: '394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2',
    summary: 'Best for accented or non-native English. Trained across 99 languages, so it has heard far more pronunciation variation. Slightly weaker than Medium on technical jargon.' },
]
const modelsDir = path.join(dataDir, 'Models')
const modelFile = (m) => (m.bundled ? bundledModel : path.join(modelsDir, m.file))
const selectedModel = () => {
  const m = MODELS.find((x) => x.id === ud.selectedSpeechModel)
  return m && fs.existsSync(modelFile(m)) ? m : MODELS[1]
}
const downloads = {}

function modelsView() {
  const selected = selectedModel().id
  return MODELS.map(({ id, name, file, sizeMB, summary, bundled }) => ({
    id, name, file, sizeMB, summary, bundled: Boolean(bundled), installed: fs.existsSync(modelFile(MODELS.find((m) => m.id === id))),
    selected: id === selected, progress: downloads[id] ?? null,
  }))
}

async function downloadModel(id) {
  const m = MODELS.find((x) => x.id === id)
  if (!m || m.bundled || downloads[id] !== undefined) return
  downloads[id] = 0
  changed()
  fs.mkdirSync(modelsDir, { recursive: true })
  const partial = path.join(modelsDir, m.file + '.download')
  try {
    const response = await fetch(`https://huggingface.co/ggerganov/whisper.cpp/resolve/0b364b566045a405be7225ee1e415a073e04da77/${m.file}`)
    if (!response.ok) throw new Error(`HTTP ${response.status}`)
    const total = Number(response.headers.get('content-length')) || m.sizeMB * 1e6
    const hash = require('node:crypto').createHash('sha256')
    const out = fs.createWriteStream(partial)
    let received = 0
    let shown = 0
    for await (const chunk of response.body) {
      hash.update(chunk)
      if (!out.write(chunk)) await new Promise((r) => out.once('drain', r))
      received += chunk.length
      if (received / total - shown > 0.01) { shown = received / total; downloads[id] = Math.min(0.99, shown); changed() }
    }
    await new Promise((resolve, reject) => out.end((e) => (e ? reject(e) : resolve())))
    if (hash.digest('hex') !== m.sha256) throw new Error('The download was damaged')
    fs.renameSync(partial, modelFile(m))
    delete downloads[id]
    selectModel(id)
  } catch (error) {
    fs.rmSync(partial, { force: true })
    delete downloads[id]
    flash('error', `Couldn’t download ${m.name}`, 4000)
    changed()
  }
}

function selectModel(id) {
  if (!MODELS.some((m) => m.id === id)) return
  ud.selectedSpeechModel = id
  saveLater('userdata', 300)
  restartEngine()
}

function removeModel(id) {
  const m = MODELS.find((x) => x.id === id)
  if (!m || m.bundled) return
  const wasSelected = selectedModel().id === id
  fs.rmSync(modelFile(m), { force: true })
  if (wasSelected) selectModel('small')
  changed()
}

// ---------- Speech engine: whisper.cpp's server on a private local port ----------

let server = null
let port = 0
let engine = { ready: false }
let quitting = false

const freePort = () => new Promise((resolve, reject) => {
  const s = net.createServer()
  s.on('error', reject)
  s.listen(0, '127.0.0.1', () => { const p = s.address().port; s.close(() => resolve(p)) })
})

async function startEngine() {
  const modelPath = modelFile(selectedModel())
  if (!fs.existsSync(serverBin) || !fs.existsSync(modelPath)) {
    engine = { ready: false, problem: 'Speech model missing' }
    return changed()
  }
  engine = { ready: false }
  changed()
  port = await freePort()
  const threads = Math.max(1, Math.min(8, os.cpus().length - 2))
  const child = spawn(serverBin, ['-m', modelPath, '--host', '127.0.0.1', '--port', String(port), '-t', String(threads), '-l', 'en', '-sns', ...vadArgs], {
    cwd: serverDir, env: { ...process.env, LD_LIBRARY_PATH: serverDir }, stdio: 'ignore', windowsHide: true,
  })
  server = child
  const died = () => {
    if (server !== child) return
    server = null
    engine = { ready: false, problem: 'Could not load model' }
    changed()
    if (!quitting) setTimeout(startEngine, 10000)
  }
  child.on('exit', died)
  child.on('error', died)
  while (server === child) {
    try {
      if ((await fetch(`http://127.0.0.1:${port}/`)).ok) { engine = { ready: true }; return changed() }
    } catch {}
    await sleep(250)
  }
}

function restartEngine() {
  const old = server
  server = null
  old?.kill()
  startEngine()
}

async function transcribe(samples) {
  for (let i = 0; !engine.ready && !engine.problem && i < 480; i++) await sleep(250)
  if (!engine.ready) throw new Error(engine.problem || 'Speech model missing')
  const form = new FormData()
  form.append('file', new Blob([text.wav(samples)], { type: 'audio/wav' }), 'audio.wav')
  form.append('response_format', 'verbose_json')
  form.append('language', 'en')
  form.append('no_speech_thold', '0.6')
  const prompt = ud.speechBiasEnabled ? text.biasPrompt(ud.words) : ''
  if (prompt) {
    form.append('prompt', prompt)
    form.append('carry_initial_prompt', 'true')
  }
  const response = await fetch(`http://127.0.0.1:${port}/inference`, { method: 'POST', body: form })
  // whisper-server 1.9.2 answers 500 when VAD finds no speech in the clip.
  if (response.status === 500 && vadArgs.length) return []
  const json = await response.json().catch(() => ({}))
  if (!response.ok || json.error) throw new Error('Transcription failed')
  return (json.segments || []).map((s) => ({ start: s.start, end: s.end, text: s.text }))
}

// ---------- Capture: the pill window owns the microphone and Windows loopback ----------

const sinks = { mic: [], system: [] }
const capture = (command) => pillWindow?.webContents.send('capture', command)
const sound = (name) => ud.soundsEnabled && capture({ cmd: 'sound', name })

function openStream(stream, sink) {
  sink.stopped = new Promise((resolve) => (sink.onStopped = resolve))
  sinks[stream].push(sink)
  if (stream === 'mic') capture({ cmd: 'open', stream, deviceId: ud.microphoneUID })
  else pillWindow.webContents.executeJavaScript('startSystemAudio()', true).catch(() => {})
}

async function closeStream(stream, sink) {
  if (!sink.closeSent) {
    sink.closeSent = true
    capture({ cmd: 'close', stream })
  }
  await Promise.race([sink.stopped, sleep(2000)])
  const i = sinks[stream].indexOf(sink)
  if (i >= 0) sinks[stream].splice(i, 1)
}

ipcMain.on('pcm', (_e, stream, buffer) => sinks[stream]?.[0]?.push(new Int16Array(buffer)))
ipcMain.on('capture:event', (_e, event) => {
  if (event.type === 'stopped') sinks[event.stream]?.shift()?.onStopped()
  if (event.type === 'error') sinks[event.stream]?.[0]?.error?.(event.message)
})

function micLevel(samples) {
  let sum = 0
  for (const s of samples) sum += s * s
  const db = 20 * Math.log10(Math.sqrt(sum / samples.length) / 32768 + 1e-9)
  return Math.min(1, Math.max(0, (db + 50) / 45))
}

function concat(chunks) {
  const out = new Int16Array(chunks.reduce((n, c) => n + c.length, 0))
  let offset = 0
  for (const c of chunks) { out.set(c, offset); offset += c.length }
  return out
}

// ---------- Pill ----------

let pillWindow = null
let pillState = { state: 'rest' }
let pillTimer = null
const idlePill = () => (ud.alwaysShowPill ? 'rest' : 'hidden')

function setPill(state, message = '', extra = {}) {
  clearTimeout(pillTimer)
  pillState = { state, message, ...extra }
  if (!pillWindow) return
  pillWindow.setIgnoreMouseEvents(!['island', 'hover', 'dot'].includes(state), { forward: true })
  pillWindow.webContents.send('pill', pillState)
  if (state === 'hidden') pillWindow.hide()
  else if (!pillWindow.isVisible()) pillWindow.showInactive()
}

// An error nobody saw stays as a dot; clicking it shows the message again.
function flash(state, message, ms) {
  setPill(state, message)
  pillTimer = setTimeout(() => (state === 'error' ? setPill('dot', message) : setPill(idlePill())), ms)
}

const PILL = { width: 400, height: 240 }
function placePill() {
  const { workArea } = screen.getPrimaryDisplay()
  pillWindow.setBounds({ x: workArea.x + Math.round((workArea.width - PILL.width) / 2), y: workArea.y + workArea.height - PILL.height - 10, ...PILL })
}

function createPill() {
  pillWindow = new BrowserWindow({
    ...PILL, show: false, transparent: true, frame: false, resizable: false, movable: false,
    focusable: false, skipTaskbar: true, alwaysOnTop: true, hasShadow: false, ...(WIN && { type: 'toolbar' }),
    webPreferences: { preload: path.join(__dirname, 'preload.js'), sandbox: true, backgroundThrottling: false },
  })
  pillWindow.setAlwaysOnTop(true, 'screen-saver')
  pillWindow.setVisibleOnAllWorkspaces(true)
  pillWindow.setIgnoreMouseEvents(true, { forward: true })
  placePill()
  screen.on('display-metrics-changed', placePill)
  pillWindow.webContents.on('did-finish-load', () => setPill(pillState.state === 'rest' ? idlePill() : pillState.state, pillState.message))
  pillWindow.webContents.on('render-process-gone', () => pillWindow.reload())
  pillWindow.loadFile(path.join(__dirname, 'pill.html'))
}

ipcMain.on('pill:mouse', (_e, event) => {
  if (event === 'enter') {
    pillWindow.setIgnoreMouseEvents(false)
    if (pillState.state === 'rest') setPill('hover')
  } else if (event === 'leave') {
    pillWindow.setIgnoreMouseEvents(true, { forward: true })
    if (pillState.state === 'hover') setPill(idlePill())
  } else if (event === 'click' && pillState.state === 'hover') {
    toggleHandsFree('app')
  } else if (event === 'click' && pillState.state === 'dot') {
    setPill('error', pillState.message)
    pillTimer = setTimeout(() => setPill(idlePill()), 4000)
  } else if (event === 'long-press') {
    showApp('library')
  } else if (event === 'island-copy' && pillState.state === 'island') {
    clipboard.writeText(pillState.island)
    flash('notice', 'Copied', 700)
  } else if (event === 'island-note' && pillState.state === 'island') {
    createNote(pillState.island, 'dictated')
    flash('notice', 'Saved', 700)
  } else if (event === 'island-close' && pillState.state === 'island') {
    setPill(idlePill())
  } else if (event === 'menu') {
    Menu.buildFromTemplate([
      { label: 'Open Utter', click: () => showApp('library') },
      { label: 'Quit Utter', click: () => app.quit() },
    ]).popup()
  }
})

// ---------- Dictation turns ----------

const { uIOhook, UiohookKey: K } = require('uiohook-napi')
// PCs have no Fn key Windows can see, so the default is the two keys beside where Fn sits on a Mac.
const HOTKEYS = [
  { id: 'ctrlWin', name: WIN ? 'Ctrl + Windows' : 'Ctrl + Super', keys: [K.Ctrl, K.Meta] },
  { id: 'rightControl', name: 'Right Ctrl', keys: [K.CtrlRight] },
  { id: 'rightOption', name: 'Right Alt', keys: [K.AltRight] },
  { id: 'rightCommand', name: WIN ? 'Right Windows key' : 'Right Super', keys: [K.MetaRight] },
]
const hotkey = () => HOTKEYS.find((h) => h.id === ud.hotkeyId) || HOTKEYS[0]
const MODIFIERS = new Set([K.Ctrl, K.CtrlRight, K.Shift, K.ShiftRight, K.Alt, K.AltRight, K.Meta, K.MetaRight])

let dictation = 'idle'
let current = null
let turnId = 0
let armedNoteId = null

function startTurn(mode, destination) {
  if (meeting && meeting.state !== 'failed') return flash('error', 'Recording a meeting - stop it first', 4000)
  if (engine.problem) return flash('error', engine.problem, 4000)
  if (armedNoteId) destination = 'note'
  const turn = { id: ++turnId, mode, destination, noteId: armedNoteId, chunks: [], heard: false, lastLoud: Date.now() }
  armedNoteId = null
  current = turn
  dictation = mode
  hideSurface('hub')
  if (ud.muteMusicWhileDictating) turn.media = pauseMedia()
  turn.focus = winHelper.ask('focus')
  if (ud.livePreviewEnabled) setTimeout(() => preview(turn), 900)
  sound('start')
  turn.sink = {
    push: (samples) => {
      turn.chunks.push(samples)
      companion.signal('level', { level: micLevel(samples) })
      if (turn.mode !== 'handsFree' || turn.closing) return
      if (text.peak(samples) > 500) { turn.heard = true; turn.lastLoud = Date.now() }
      else if (turn.heard && Date.now() - turn.lastLoud >= 3000) stopTurn()
    },
    error: () => {
      if (turn.id !== turnId) return
      discardTurn()
      flash('error', 'Couldn’t start the microphone', 4000)
    },
  }
  openStream('mic', turn.sink)
  showTurn()
}

function showTurn() {
  if (!current) return
  setPill({ note: 'note', memory: 'memory' }[current.destination] || (current.mode === 'handsFree' ? 'handsFree' : 'listening'))
  companion.signal('listening', { mode: current.mode, destination: current.destination })
  changed()
}

function discardTurn() {
  const turn = current
  turnId++
  current = null
  dictation = 'idle'
  if (turn && !turn.closing) {
    closeStream('mic', turn.sink)
    if (turn.media) turn.media.then(resumeMedia)
  }
  changed()
}

async function stopTurn() {
  const turn = current
  if (!turn || turn.closing) return
  turn.closing = true
  dictation = 'processing'
  setPill('thinking')
  companion.signal('thinking')
  changed()
  await closeStream('mic', turn.sink)
  sound('stop')
  if (turn.media) turn.media.then(resumeMedia)
  if (turn.id !== turnId) return
  const samples = concat(turn.chunks)
  const trimmed = text.trimSilence(samples)
  if (trimmed.length * 2 <= 640) return endTurn(turn, 'error', 'No speech detected')
  let raw
  try {
    raw = (await transcribe(trimmed)).map((s) => s.text).join('').trim()
  } catch (error) {
    return endTurn(turn, 'error', error.message)
  }
  if (turn.id !== turnId) return
  if (!text.isUsable(raw)) return endTurn(turn, 'error', 'No speech detected')
  const formatted = text.formatText(raw, ud.spokenPunctuation)
  if (turn.destination === 'memory') {
    const { message } = await companion.remember(formatted)
    return endTurn(turn, 'notice', message)
  }
  const command = ud.voiceCommands ? text.voiceCommand(formatted) : null
  if (command === 'newNote' || command === 'continueNote') return route(turn, command)
  const holding = turn.destination === 'app' && await holdsTranscript(turn)
  if (turn.id !== turnId) return
  if (command && turn.destination === 'app') {
    if (holding) return endTurn(turn, 'notice', 'Command skipped: no text box')
    for (const [key, mods] of ACTIONS[command]) { uIOhook.keyTap(key, mods); await sleep(3) }
    return endTurn(turn, 'done')
  }
  const prepared = text.applySnippets(text.correct(formatted, ud.words), ud.snippets, await clipboard.readText().catch(() => ''), new Date())
  if (turn.destination === 'note') {
    const note = findNote(turn.noteId) || (ud.captureAppendsToOpenNote && findNote(openNoteId)) || createNote('', 'dictated')
    openNoteId = note.id
    appendToNote(note, prepared)
  } else {
    if (!holding) await paste(prepared)
    if (ud.keepHistory) {
      const seconds = Math.round((samples.length / text.RATE) * 100) / 100
      history.unshift({ id: randomUUID().toUpperCase(), text: prepared, ts: isoSeconds(), lang: 'English', ...(seconds && { dur: String(seconds) }) })
      history = history.slice(0, 1000)
      saveLater('history', 50)
    }
  }
  addWords(prepared.split(' ').filter(Boolean).length)
  companion.signal('delivered', { words: prepared.split(' ').filter(Boolean).length, total: ud.companionProgress.dictationWords, destination: turn.destination })
  if (holding) return endTurn(turn, 'island', prepared)
  endTurn(turn, 'done')
}

// Like the Mac: hold the words on the pill only when the user is now in a different app whose focus
// takes no text. Without the Windows helper nothing is known about focus, so it pastes.
async function holdsTranscript(turn) {
  const [before, now] = await Promise.all([turn.focus, winHelper.ask('focus', 400)])
  return Boolean(before && now && before.pid !== now.pid && now.editable === false)
}

async function preview(turn) {
  while (current === turn && !turn.closing) {
    const tail = []
    let samples = 0
    for (let i = turn.chunks.length - 1; i >= 0 && samples < 10 * text.RATE; i--) { tail.unshift(turn.chunks[i]); samples += turn.chunks[i].length }
    if (samples >= 0.6 * text.RATE) {
      const segments = await transcribe(concat(tail)).catch(() => null)
      if (current !== turn || turn.closing) return
      const caption = (segments || []).map((s) => s.text).join('').trim()
      if (text.isUsable(caption)) setPill(pillState.state, '', { caption: caption.slice(-160) })
    }
    await sleep(700)
  }
}

// ---------- Pause music while dictating ----------

async function pauseMedia() {
  if (WIN) return winHelper.ask('media-pause')
  if (!LINUX) return null
  const players = (await run('gdbus', ['call', '--session', '--dest', 'org.freedesktop.DBus', '--object-path', '/org/freedesktop/DBus',
    '--method', 'org.freedesktop.DBus.ListNames'])).match(/org\.mpris\.MediaPlayer2\.[^',\s]+/g) || []
  const paused = []
  for (const player of players) {
    const status = await run('gdbus', ['call', '--session', '--dest', player, '--object-path', '/org/mpris/MediaPlayer2',
      '--method', 'org.freedesktop.DBus.Properties.Get', 'org.mpris.MediaPlayer2.Player', 'PlaybackStatus'])
    if (!status.includes('Playing')) continue
    await run('gdbus', ['call', '--session', '--dest', player, '--object-path', '/org/mpris/MediaPlayer2', '--method', 'org.mpris.MediaPlayer2.Player.Pause'])
    paused.push(player)
  }
  return { players: paused }
}

async function resumeMedia(paused) {
  if (WIN && paused?.paused) return winHelper.ask('media-resume')
  for (const player of paused?.players || []) {
    await run('gdbus', ['call', '--session', '--dest', player, '--object-path', '/org/mpris/MediaPlayer2', '--method', 'org.mpris.MediaPlayer2.Player.Play'])
  }
}

const run = (cmd, args) => new Promise((resolve) => {
  require('node:child_process').execFile(cmd, args, { timeout: 3000, windowsHide: true }, (_error, stdout) => resolve(String(stdout || '')))
})

const ACTIONS = {
  undo: [[K.Z, [K.Ctrl]]], selectAll: [[K.A, [K.Ctrl]]], newLine: [[K.Enter, []]], newParagraph: [[K.Enter, []], [K.Enter, []]],
  goToEnd: [[K.End, [K.Ctrl]]], copy: [[K.C, [K.Ctrl]]], paste: [[K.V, [K.Ctrl]]],
}

function route(turn, command) {
  let message = 'New note - keep talking'
  let note = command === 'continueNote' && findNote(openNoteId)
  if (note) message = 'Adding to the open note'
  else {
    if (command === 'continueNote') message = 'No note open - starting one'
    note = createNote('', 'dictated')
  }
  openNoteId = armedNoteId = note.id
  endTurn(turn, 'notice', message)
}

function endTurn(turn, kind, message) {
  if (turn.id !== turnId) return
  current = null
  dictation = 'idle'
  companion.signal(kind, { message })
  changed()
  if (kind === 'done') { sound('done'); flash('done', '', 450) }
  else if (kind === 'island') { sound('done'); setPill('island', '', { island: message }) }
  else if (kind === 'notice') { sound('done'); flash('notice', message, 4000) }
  else { sound('error'); flash('error', message, 4000) }
}

function toggleHandsFree(destination) {
  if (!current) return startTurn('handsFree', destination)
  if (current.closing) return
  if (current.mode === 'handsFree' && current.destination === destination) return stopTurn()
  current.mode = 'handsFree'
  current.destination = destination
  dictation = 'handsFree'
  showTurn()
}

function cancelTurn() {
  if (!current) return
  discardTurn()
  flash('notice', 'Cancelled', 1200)
}

// ponytail: a fixed wait before restoring the clipboard; raise it if a slow app pastes the old contents.
async function paste(value) {
  // Wait for the hold keys to come up, or Windows + V would open clipboard history.
  for (let i = 0; i < 50 && down.size; i++) await sleep(20)
  const items = await clipboard.read().catch(() => [])
  const saved = await Promise.all(items.map(async (item) => Object.fromEntries((await Promise.all(
    item.types.map((type) => item.getType(type).then((data) => [type, data], () => null)))).filter(Boolean))))
  await clipboard.writeText(value)
  await sleep(30)
  uIOhook.keyTap(K.V, [K.Ctrl])
  await sleep(400)
  if ((await clipboard.readText()) !== value) return
  const restore = saved.filter((entry) => Object.keys(entry).length)
  if (!restore.length) return clipboard.clear()
  await clipboard.write(restore.map((entry) => new ClipboardItem(entry))).catch(() => {})
}

async function pasteAgain(value) {
  appWindow?.hide()
  hideSurface('hub')
  for (let i = 0; i < 25 && BrowserWindow.getFocusedWindow(); i++) await sleep(20)
  await sleep(120)
  await paste(value)
}

let held = false
let pressedAt = 0
let lastTap = null
let stopPress = false
const down = new Set()
const MASKS = [[K.Ctrl, K.CtrlRight, 'ctrlKey'], [K.Meta, K.MetaRight, 'metaKey'], [K.Alt, K.AltRight, 'altKey'], [K.Shift, K.ShiftRight, 'shiftKey']]

// A key-up lost to Win+L or a UAC prompt would leave a modifier "held"; the event's own flags correct it.
function prune(e) {
  for (const [left, right, flag] of MASKS) if (!e[flag] && e.keycode !== left && e.keycode !== right) { down.delete(left); down.delete(right) }
}

function startKeys() {
  uIOhook.on('keydown', (e) => {
    prune(e)
    if (MODIFIERS.has(e.keycode)) down.add(e.keycode)
    const { keys } = hotkey()
    if (keys.includes(e.keycode)) {
      if (held || !keys.every((k) => down.has(k))) return
      held = true
      pressedAt = Date.now()
      if (current?.mode === 'handsFree' && !current.closing) { stopPress = true; return stopTurn() }
      const doubleTap = ud.doubleTapHotkeyForHandsFree && lastTap && lastTap.duration < 350 && pressedAt - lastTap.releasedAt <= 380
      lastTap = null
      if (doubleTap) { discardTurn(); return startTurn('handsFree', 'app') }
      if (!current) startTurn('recording', 'app')
      return
    }
    if (e.keycode === K.Escape && !e.ctrlKey && !e.altKey && !e.shiftKey && !e.metaKey) {
      if (pillState.state === 'island') return setPill(idlePill())
      return cancelTurn()
    }
    // The hotkey was the start of a shortcut, not dictation.
    if (held && !MODIFIERS.has(e.keycode) && current?.mode === 'recording' && !current.closing) discardTurn()
  })
  uIOhook.on('keyup', (e) => {
    down.delete(e.keycode)
    if (!hotkey().keys.includes(e.keycode) || !held) return
    held = false
    if (stopPress) { stopPress = false; return }
    lastTap = { duration: Date.now() - pressedAt, releasedAt: Date.now() }
    if (current?.mode === 'recording') stopTurn()
  })
  uIOhook.start()
}

// ---------- Meetings: microphone as "You", system audio as "Others" ----------

let meeting = null

function meetingView() {
  if (!meeting) return null
  const { state, noteId, elapsed, since, problem, echo } = meeting
  const listening = state === 'recording' ? (Date.now() - since) / 1000 + elapsed : elapsed
  return { state, noteId, elapsed, since, problem, echo, othersQuiet: state === 'recording' && !meeting.othersHeard && listening > 45 }
}

const newTrack = () => ({ chunks: [], length: 0, offset: 0, upTo: 0, fresh: true })

function trackSink(m, key) {
  return {
    push: (samples) => {
      const t = m[key]
      if (t.fresh) { t.offset = t.upTo = Math.max(t.upTo, (Date.now() - m.startedAt) / 1000 - samples.length / text.RATE); t.fresh = false }
      t.chunks.push(samples)
      t.length += samples.length
    },
    error: () => {
      if (key === 'mic') failMeeting(m, 'Couldn’t start the microphone')
    },
  }
}

function openMeetingStreams(m) {
  m.mic.fresh = m.sys.fresh = true
  m.micSink = trackSink(m, 'mic')
  openStream('mic', m.micSink)
  m.sysSink = trackSink(m, 'sys')
  if (WIN) return openStream('system', m.sysSink)
  if (!LINUX) return
  let carry = Buffer.alloc(0)
  const proc = spawn('parec', ['--device=@DEFAULT_MONITOR@', '--raw', '--format=s16le', `--rate=${text.RATE}`, '--channels=1', '--latency-msec=100'],
    { stdio: ['ignore', 'pipe', 'ignore'] })
  proc.stdout.on('data', (data) => {
    const all = Buffer.concat([carry, data])
    const even = all.length & ~1
    carry = all.subarray(even)
    if (even) m.sysSink.push(new Int16Array(all.buffer.slice(all.byteOffset, all.byteOffset + even)))
  })
  proc.on('error', () => {})
  m.sysSink.closed = new Promise((resolve) => proc.on('close', resolve))
  m.parec = proc
}

async function closeMeetingStreams(m) {
  const waits = [closeStream('mic', m.micSink)]
  if (WIN) waits.push(closeStream('system', m.sysSink))
  if (m.parec) { m.parec.kill(); waits.push(Promise.race([m.sysSink.closed, sleep(2000)])); m.parec = null }
  await Promise.all(waits)
}

function startMeeting() {
  if (meeting?.state === 'failed') meeting = null
  if (meeting || current) return
  const callApp = offer?.app || null
  dismissOffer()
  const note = createNote(text.meetingHeader(new Date(), callApp || ''), 'meeting')
  const now = Date.now()
  meeting = { state: 'recording', noteId: note.id, header: note.body, callApp, callLastSeen: now, elapsed: 0, since: now, startedAt: now, mic: newTrack(), sys: newTrack(),
    pending: [], others: [], echo: false, othersHeard: false, queue: Promise.resolve() }
  const m = meeting
  openMeetingStreams(m)
  m.timer = setInterval(() => {
    if (m.state === 'recording' && !m.draining && (m.mic.length >= WINDOW || m.sys.length >= WINDOW)) {
      m.draining = true
      drain(m, false).finally(() => (m.draining = false))
    }
    const quiet = meetingView()?.othersQuiet
    if (quiet !== m.quiet) { m.quiet = quiet; changed() }
  }, 1000)
  showApp('meetings')
  companion.signal('meeting', { state: 'recording' })
  changed()
}

function failMeeting(m, problem) {
  if (meeting !== m || m.state === 'failed') return
  clearInterval(m.timer)
  closeMeetingStreams(m)
  if (findNote(m.noteId)?.body === m.header) notes = notes.filter((n) => n.id !== m.noteId)
  saveNow('notes')
  m.state = 'failed'
  m.problem = problem
  companion.signal('meeting', { state: 'failed' })
  changed()
}

function drain(m, final) {
  m.queue = m.queue.then(async () => {
    for (const key of ['sys', 'mic']) {
      const t = m[key]
      while (t.length >= WINDOW || (final && t.length >= text.RATE)) {
        const n = Math.min(t.length, WINDOW)
        const all = concat(t.chunks)
        t.chunks = n < all.length ? [all.subarray(n)] : []
        t.length = all.length - n
        const at = t.offset
        t.offset += n / text.RATE
        await transcribeWindow(m, key, all.subarray(0, n), at)
        t.upTo = t.offset
      }
      if (final) { t.offset += t.length / text.RATE; t.upTo = t.offset; t.chunks = []; t.length = 0 }
    }
    releaseTurns(m, final)
  })
  return m.queue
}

async function transcribeWindow(m, key, chunk, at0) {
  if (text.peak(chunk) < 300) return
  if (key === 'sys') m.othersHeard = true
  let segments = null
  for (let attempt = 0; attempt < 3 && !segments; attempt++) {
    segments = await transcribe(chunk).catch(() => null)
    if (!segments) await sleep(1000)
  }
  for (const turn of text.turns(segments || [])) {
    const line = text.formatText(turn.text, ud.spokenPunctuation)
    if (!text.isUsable(line)) continue
    const at = at0 + turn.start
    const end = at0 + turn.end
    if (key === 'sys') m.others.push({ at, end, text: line })
    else {
      const heard = m.others.filter((o) => o.end >= at - 2 && o.at <= end + 2).map((o) => o.text).join(' ')
      if (heard && text.isEcho(line, heard)) { m.echo = true; changed(); continue }
    }
    m.pending.push({ at, role: key === 'sys' ? 'others' : 'you', text: line })
  }
  const latest = Math.max(0, ...m.others.map((o) => o.end))
  m.others = m.others.filter((o) => o.end >= latest - 120)
}

function releaseTurns(m, final) {
  const lo = Math.min(m.mic.upTo, m.sys.upTo)
  const hi = Math.max(m.mic.upTo, m.sys.upTo)
  const ready = text.release(m.pending, final ? Infinity : Math.max(lo, hi - 60))
  const note = findNote(m.noteId)
  if (!ready.length || !note) return
  const labels = { ...SPEAKERS, ...note.speakers }
  appendToNote(note, ready.map((p) => text.turnLine(labels[p.role], p.text)).join('\n\n'))
}

async function meetingCommand(command, savedMessage = 'Meeting saved') {
  const m = meeting
  if (command === 'start') return startMeeting()
  if (!m) return
  if (command === 'pause' && m.state === 'recording') {
    m.state = 'paused'
    m.elapsed += (Date.now() - m.since) / 1000
    changed()
    await closeMeetingStreams(m)
    await drain(m, true)
  } else if (command === 'resume' && m.state === 'paused') {
    m.state = 'recording'
    m.since = Date.now()
    openMeetingStreams(m)
    changed()
  } else if (command === 'stop') {
    if (m.state === 'failed') { meeting = null; return changed() }
    if (m.state === 'finishing') return
    if (m.state === 'recording') m.elapsed += (Date.now() - m.since) / 1000
    const wasRecording = m.state === 'recording'
    m.state = 'finishing'
    changed()
    if (wasRecording) await closeMeetingStreams(m)
    await drain(m, true)
    clearInterval(m.timer)
    const note = findNote(m.noteId)
    if (note) { note.recordedSeconds = Math.round(m.elapsed * 10) / 10; saveNow('notes') }
    meeting = null
    companion.signal('meeting', { state: 'saved', minutes: Math.round(m.elapsed / 60) })
    flash('notice', savedMessage, 2500)
    changed()
  }
}

// ---------- Call detection: which call app is using the microphone ----------

const CALL_APPS = [[/zoom/i, 'Zoom'], [/teams/i, 'Teams'], [/webex|ciscocollab|atmgr/i, 'Webex'], [/slack/i, 'Slack'], [/discord/i, 'Discord']]
const callApp = (name) => CALL_APPS.find(([pattern]) => pattern.test(name))?.[1]

async function microphoneUsers() {
  if (WIN) {
    const out = await run('reg', ['query', 'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\CapabilityAccessManager\\ConsentStore\\microphone', '/s', '/v', 'LastUsedTimeStop'])
    const users = []
    let key = ''
    for (const line of out.split(/\r?\n/)) {
      if (line.startsWith('HKEY_')) key = line.split('\\').pop()
      else if (/LastUsedTimeStop\s+REG_QWORD\s+0x0\s*$/.test(line)) users.push(key.split('#').pop())
    }
    return users
  }
  if (LINUX) return [...(await run('pactl', ['list', 'source-outputs'])).matchAll(/application\.(?:name|process\.binary) = "([^"]*)"/g)].map((m) => m[1])
  return []
}

const callSeen = {}
let offeredFor = null

async function watchCalls() {
  const apps = new Set((await microphoneUsers()).map(callApp).filter(Boolean))
  const now = Date.now()
  for (const app of Object.keys(callSeen)) if (!apps.has(app)) delete callSeen[app]
  for (const app of apps) callSeen[app] ??= now
  if (offeredFor && !apps.has(offeredFor)) offeredFor = null
  if (meeting?.callApp && meeting.state === 'recording') {
    if (apps.has(meeting.callApp)) meeting.callLastSeen = now
    else if (now - meeting.callLastSeen >= 20000) meetingCommand('stop', 'Call ended. Meeting saved')
  }
  if (offer && !apps.has(offer.app)) dismissOffer()
  if (!ud.offerToTranscribeCalls || meeting || offer) return
  const confirmed = [...apps].find((app) => now - callSeen[app] >= 5000 && app !== offeredFor)
  if (!confirmed) return
  offeredFor = confirmed
  offer = { app: confirmed }
  changed()
  showSurface('offer')
}

function dismissOffer() {
  if (!offer) return
  offer = null
  hideSurface('offer')
  changed()
}

// ---------- Windows, tray, state ----------

let appWindow = null
let tray = null

function publicState() {
  return {
    platform: process.platform, version: app.getVersion(), hotkeyLabel: hotkey().name,
    hotkeys: HOTKEYS.map(({ id, name }) => ({ id, name })),
    settings: Object.fromEntries(SETTINGS.map((k) => [k, ud[k]])),
    words: ud.words, snippets: ud.snippets, history, notes, openNoteId, todayWords: todayWords(),
    meeting: meetingView(), engine, dictation, models: modelsView(), account, accountProblem, signInSkipped: Boolean(ud.signInSkipped), crashed, offer,
    companion: companion.view(), companionSettings: Object.fromEntries(Object.entries(ud).filter(([k]) => k.startsWith('companion'))),
  }
}

let changeTimer = null
function changed() {
  if (changeTimer) return
  changeTimer = setTimeout(() => {
    changeTimer = null
    broadcast('state', publicState())
    updateTray()
  }, 30)
}

function showApp(view) {
  if (!appWindow) {
    const { workArea } = screen.getPrimaryDisplay()
    appWindow = new BrowserWindow({
      width: Math.min(1380, workArea.width - 40), height: Math.min(960, workArea.height - 40), minWidth: 1000, minHeight: 680,
      show: false, title: 'Utter', icon: asset('icon.png'), autoHideMenuBar: true,
      backgroundColor: nativeTheme.shouldUseDarkColors ? '#15171C' : '#F8F9FB',
      webPreferences: { preload: path.join(__dirname, 'preload.js'), sandbox: true },
    })
    appWindow.removeMenu()
    appWindow.on('close', (e) => { if (!quitting) { e.preventDefault(); appWindow.hide() } })
    appWindow.once('ready-to-show', () => appWindow.show())
    appWindow.webContents.once('did-finish-load', () => view && appWindow.webContents.send('show', view))
    appWindow.loadFile(path.join(__dirname, 'app.html'))
    return
  }
  if (appWindow.isMinimized()) appWindow.restore()
  appWindow.show()
  appWindow.focus()
  if (view) appWindow.webContents.send('show', view)
}

// The hub, Report an Issue, What's New and the call offer are app.html in their own windows.
const surfaces = {}
const SURFACES = {
  hub: { width: 384, height: 525, frame: false, transparent: true, resizable: false, skipTaskbar: true, alwaysOnTop: true },
  report: { width: 660, height: 700, title: 'Report an Issue', minimizable: false },
  'whats-new': { width: 560, height: 620, title: 'What’s New', minimizable: false },
  offer: { width: 268, height: 146, frame: false, transparent: true, resizable: false, skipTaskbar: true, alwaysOnTop: true, focusable: false },
}

function showSurface(name) {
  let win = surfaces[name]
  if (!win || win.isDestroyed()) {
    win = surfaces[name] = new BrowserWindow({
      show: false, icon: asset('icon.png'), autoHideMenuBar: true,
      backgroundColor: SURFACES[name].transparent ? '#00000000' : nativeTheme.shouldUseDarkColors ? '#15171C' : '#F8F9FB', ...SURFACES[name],
      webPreferences: { preload: path.join(__dirname, 'preload.js'), sandbox: true },
    })
    win.removeMenu()
    if (name === 'hub') win.on('blur', () => { win.hide(); hubHiddenAt = Date.now() })
    win.loadFile(path.join(__dirname, 'app.html'), { hash: name })
    win.once('ready-to-show', () => { placeSurface(name); name === 'offer' ? win.showInactive() : win.show() })
    return win
  }
  placeSurface(name)
  name === 'offer' ? win.showInactive() : (win.show(), win.focus())
  return win
}

function placeSurface(name) {
  const win = surfaces[name]
  const [w, h] = win.getSize()
  if (name === 'hub') {
    const tb = tray?.getBounds()
    const { workArea } = screen.getDisplayMatching(tb?.width ? tb : screen.getPrimaryDisplay().bounds)
    const x = tb?.width ? tb.x + tb.width / 2 - w / 2 : workArea.x + workArea.width - w - 12
    const y = tb?.width && tb.y > workArea.y + workArea.height / 2 ? workArea.y + workArea.height - h - 8 : workArea.y + 8
    win.setPosition(Math.round(Math.min(Math.max(x, workArea.x + 8), workArea.x + workArea.width - w - 8)), Math.round(y))
  } else if (name === 'offer') {
    const { workArea } = screen.getPrimaryDisplay()
    win.setPosition(workArea.x + workArea.width - w - 16, workArea.y + workArea.height - h - 16)
  }
}

const hideSurface = (name) => surfaces[name] && !surfaces[name].isDestroyed() && surfaces[name].hide()
let hubHiddenAt = 0
const toggleHub = () => {
  if (Date.now() - hubHiddenAt < 300) return
  surfaces.hub?.isVisible() ? hideSurface('hub') : showSurface('hub')
}

function showView(view) {
  hideSurface('hub')
  if (view === 'report' || view === 'whats-new') return showSurface(view)
  if (view === 'hub') return showSurface('hub')
  showApp(view)
}

function broadcast(channel, value) {
  for (const win of [appWindow, ...Object.values(surfaces)]) if (win && !win.isDestroyed()) win.webContents.send(channel, value)
}

let trayKey = ''
function updateTray() {
  if (!tray) return
  const status = !engine.ready ? (engine.problem || 'Loading the speech model') : meeting ? 'Recording a meeting'
    : dictation !== 'idle' ? 'Recording' : !ud.hasCompletedOnboarding ? 'One thing left' : `Ready · hold ${hotkey().name}`
  const key = status + (meeting ? 1 : 0)
  if (key === trayKey) return
  trayKey = key
  const dot = dictation !== 'idle' || meeting?.state === 'recording' ? 'tray-rec.png' : engine.problem || !ud.hasCompletedOnboarding ? 'tray-setup.png' : 'tray.png'
  tray.setImage(nativeImage.createFromPath(asset(dot)))
  tray.setToolTip(`Utter · ${status}`)
  tray.setContextMenu(Menu.buildFromTemplate([
    { label: status, enabled: false },
    { type: 'separator' },
    { label: 'Show Utter', click: () => showSurface('hub') },
    { label: 'Open Library', accelerator: 'Ctrl+Alt+U', registerAccelerator: false, click: () => showApp('library') },
    { label: 'Hands-free', accelerator: 'Ctrl+Alt+Space', registerAccelerator: false, click: () => toggleHandsFree('app') },
    { label: 'New note', click: () => { openNoteId = createNote().id; showApp('notes') } },
    meeting && meeting.state !== 'failed'
      ? { label: 'Stop the meeting', click: () => meetingCommand('stop') }
      : { label: 'Record a meeting', click: () => meetingCommand('start') },
    { label: 'Settings', click: () => showApp('settings') },
    { type: 'separator' },
    { label: 'Quit Utter', click: () => app.quit() },
  ]))
}

function applyLogin(on) {
  if (WIN) return app.setLoginItemSettings({ openAtLogin: on, args: ['--hidden'] })
  if (!LINUX) return
  const dir = path.join(os.homedir(), '.config', 'autostart')
  const entry = path.join(dir, 'utter.desktop')
  if (!on) return fs.rmSync(entry, { force: true })
  fs.mkdirSync(dir, { recursive: true })
  fs.writeFileSync(entry, `[Desktop Entry]\nType=Application\nName=Utter\nExec="${process.env.APPIMAGE || process.execPath}" --ozone-platform=x11 --hidden\nX-GNOME-Autostart-enabled=true\n`)
}

function osName() {
  if (WIN) return `${os.version()} (${os.release()})`
  try { return fs.readFileSync('/etc/os-release', 'utf8').match(/^PRETTY_NAME="?([^"\n]*)/m)[1] } catch { return `${os.type()} ${os.release()}` }
}

const exporters = {
  markdown: (items) => items.map((i) => `## ${i.title}\n\n${stamp(i.date)}\n\n${i.text}\n`).join('\n---\n\n'),
  csv: (items) => {
    const cell = (v) => `"${String(v).replaceAll('"', '""')}"`
    return ['Date,Kind,Words,Title,Text', ...items.map((i) => [cell(stamp(i.date)), cell(i.kind), i.words, cell(i.title), cell(i.text)].join(','))].join('\n') + '\n'
  },
  text: (items) => items.map((i) => `${stamp(i.date)}  ${i.title}\n${i.text}`).join('\n\n') + '\n',
}
function stamp(iso) {
  const d = new Date(iso)
  const p = (n) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`
}

// ---------- Account, onboarding, crash reports ----------

// Like the Mac: Google isn't connected yet, so a test email signs in and Skip lets people through.
const TEST_ACCOUNTS = new Set(['utter@gmail.com']) // ponytail: placeholder until the sign-in backend exists
let account = null
let accountProblem = null
let offer = null
const crashMarker = file('running')
const crashed = fs.existsSync(crashMarker)

function crashReports() {
  const dir = app.getPath('crashDumps')
  const found = []
  const walk = (d) => {
    for (const entry of fs.readdirSync(d, { withFileTypes: true })) {
      const p = path.join(d, entry.name)
      if (entry.isDirectory()) walk(p)
      else if (entry.name.endsWith('.dmp')) found.push({ file: p, time: fs.statSync(p).mtimeMs })
    }
  }
  try { walk(dir) } catch {}
  return found.sort((a, b) => b.time - a.time).slice(0, 10)
    .map((c) => ({ date: new Date(c.time).toISOString(), version: app.getVersion(), reason: 'Utter stopped unexpectedly', file: path.basename(c.file) }))
}

// ---------- IPC from the Library window ----------

const handle = (channel, fn) => ipcMain.handle(channel, (_e, ...args) => fn(...args))

handle('state:get', publicState)
handle('settings:set', (key, value) => {
  if (!SETTINGS.includes(key) && !key.startsWith('companion')) return
  ud[key] = value
  if (key === 'hotkeyId') ud.hotkeyName = hotkey().name
  if (key === 'appTheme') nativeTheme.themeSource = ['light', 'dark'].includes(value) ? value : 'system'
  if (key === 'alwaysShowPill' && ['rest', 'hidden'].includes(pillState.state)) setPill(idlePill())
  if (key === 'openAtLogin') applyLogin(Boolean(value))
  if (key.startsWith('companion')) companion.settingChanged(key, value)
  saveLater('userdata', 300)
  changed()
})
handle('words:set', (list) => { ud.words = list.filter((w) => typeof w === 'string'); saveLater('userdata', 300); changed() })
handle('snippets:set', (list) => {
  ud.snippets = list.filter((s) => s && typeof s.trigger === 'string').map(({ trigger, expansion }) => ({ trigger, expansion: String(expansion ?? '') }))
  saveLater('userdata', 300)
  changed()
})
handle('history:delete', (id) => { history = history.filter((e) => e.id !== id); saveLater('history', 50); changed() })
handle('history:restore', (entry) => {
  history = [...history.filter((e) => e.id !== entry.id), entry].sort((a, b) => Date.parse(b.ts) - Date.parse(a.ts))
  saveLater('history', 50)
  changed()
})
handle('history:toNote', (id) => {
  const entry = history.find((e) => e.id === id)
  return entry && createNote(entry.text, 'dictated')
})
handle('note:create', (options = {}) => createNote(options.body || '', options.source || 'typed'))
handle('note:update', (id, patch) => {
  const note = findNote(id)
  if (!note) return
  editNote(note, patch)
  saveLater('notes', 1000)
  changed()
  return note
})
handle('note:delete', (id) => {
  const note = findNote(id)
  notes = notes.filter((n) => n.id !== id)
  if (openNoteId === id) openNoteId = null
  saveNow('notes')
  changed()
  return note
})
handle('note:restore', (note) => {
  notes = [...notes.filter((n) => n.id !== note.id), note].sort(byModified)
  saveNow('notes')
  changed()
})
handle('note:open', (id) => { openNoteId = id || null })
handle('note:renameSpeaker', (id, role, name) => {
  const note = findNote(id)
  const label = String(name || '').trim()
  if (!note || !SPEAKERS[role] || !label) return
  const speakers = { ...SPEAKERS, ...note.speakers }
  editNote(note, { body: text.relabel(note.body, speakers[role], label) })
  note.speakers = { ...speakers, [role]: label }
  saveNow('notes')
  changed()
})
handle('paste:again', (value) => pasteAgain(String(value)))
handle('clipboard:copy', (value) => clipboard.writeText(String(value)))
handle('dictation:handsFree', async () => {
  if (!current) { appWindow?.hide(); hideSurface('hub'); await sleep(150) }
  toggleHandsFree('app')
})
handle('dictation:note', () => toggleHandsFree('note'))
handle('meeting', meetingCommand)
handle('export', async (format, items) => {
  const ext = { markdown: 'md', csv: 'csv', text: 'txt' }[format]
  if (!ext) return
  const { canceled, filePath } = await dialog.showSaveDialog(appWindow, { defaultPath: `Utter.${ext}`, filters: [{ name: format, extensions: [ext] }] })
  if (!canceled && filePath) fs.writeFileSync(filePath, exporters[format](items))
})
handle('reset', async () => {
  const { response } = await dialog.showMessageBox(appWindow, {
    type: 'warning', buttons: ['Reset Utter', 'Cancel'], defaultId: 1, cancelId: 1, message: 'Reset Utter?',
    detail: 'This deletes your history, notes, words and snippets on this computer and puts every setting back. It can’t be undone.',
  })
  if (response !== 0) return false
  resetting = true
  for (const name of ['history.json', 'notes.json', 'notes.previous.json', 'userdata.json']) fs.rmSync(file(name), { force: true })
  applyLogin(false)
  app.relaunch()
  app.quit()
})
handle('open:external', (url) => { if (/^(https:\/\/|ms-settings:privacy-microphone$)/.test(url)) shell.openExternal(url) })
handle('view:show', (view) => { showView(view) })
ipcMain.handle('window:close', (e) => {
  const win = BrowserWindow.fromWebContents(e.sender)
  if (win === surfaces.hub || win === surfaces.offer) win.hide()
  else win?.close()
})
handle('app:quit', () => app.quit())
ipcMain.on('window:fit', (e, height) => {
  const name = Object.keys(surfaces).find((key) => surfaces[key]?.webContents === e.sender)
  if (!name || !(height > 40)) return
  const win = surfaces[name]
  const [width, current] = win.getSize()
  if (Math.abs(current - height) < 2) return
  win.setResizable(true)
  win.setSize(width, Math.round(Math.min(height, 900)))
  win.setResizable(false)
  placeSurface(name)
})
handle('onboarding:done', () => {
  ud.hasCompletedOnboarding = true
  saveLater('userdata', 300)
  changed()
})
handle('account:signIn', () => {
  accountProblem = 'Google sign-in isn’t connected yet.'
  changed()
  return false
})
handle('account:signOut', () => {
  account = null
  accountProblem = null
  fs.rmSync(file('account.json'), { force: true })
  changed()
})
handle('account:signInEmail', (email) => {
  const normalized = String(email || '').trim().toLowerCase()
  if (!TEST_ACCOUNTS.has(normalized)) return false
  account = { name: 'Utter Test', email: normalized }
  accountProblem = null
  writeJSON('account.json', account)
  changed()
  return true
})
handle('account:skip', () => {
  ud.signInSkipped = true
  saveLater('userdata', 300)
  changed()
})
handle('model:download', downloadModel)
handle('model:remove', removeModel)
handle('model:select', selectModel)
handle('crash:list', crashReports)
handle('crash:show', () => shell.openPath(app.getPath('crashDumps')))
handle('offer:dismiss', () => dismissOffer())
handle('about', () => ({
  version: app.getVersion(), processor: os.cpus()[0]?.model.trim(), memory: `${Math.round(os.totalmem() / 2 ** 30)} GB`, os: osName(),
  model: `${selectedModel().name}  ${selectedModel().sizeMB} MB`,
}))

// ---------- Lifecycle ----------

app.on('second-instance', () => showApp('library'))
app.on('window-all-closed', () => {})
app.on('web-contents-created', (_e, contents) => {
  contents.setWindowOpenHandler(() => ({ action: 'deny' }))
  contents.on('will-navigate', (e) => e.preventDefault())
})

app.on('before-quit', (e) => {
  if (meeting && ['recording', 'paused'].includes(meeting.state) && !quitting) {
    e.preventDefault()
    meetingCommand('stop').finally(() => { quitting = true; app.quit() })
    return
  }
  quitting = true
  flushSaves()
  fs.rmSync(crashMarker, { force: true })
  server?.kill()
  winHelper.stop()
  companion.quit()
  if (!process.env.UTTER_NO_KEYS) try { uIOhook.stop() } catch {}
})

app.whenReady().then(() => {
  if (WIN) app.setAppUserModelId('utter.dictation.app')
  loadData()
  account = readJSON('account.json', null)
  fs.writeFileSync(crashMarker, String(process.pid))
  nativeTheme.themeSource = ud.appTheme
  const ours = (contents) => contents?.getURL().startsWith('file://')
  session.defaultSession.setPermissionRequestHandler((contents, permission, callback) => callback(ours(contents) && ['media', 'display-capture'].includes(permission)))
  if (LINUX) session.defaultSession.setSpellCheckerEnabled(false)
  session.defaultSession.setPermissionCheckHandler((contents, permission) => ours(contents) && permission === 'media')
  session.defaultSession.setDisplayMediaRequestHandler((_request, callback) => {
    desktopCapturer.getSources({ types: ['screen'] }).then((sources) => callback({ video: sources[0], audio: 'loopback' })).catch(() => callback(null))
  })

  createPill()
  companion.init({ ud, saveUserdata: () => saveLater('userdata', 300), changed, dataDir, flash, showApp,
    preload: path.join(__dirname, 'preload.js'), page: (name) => path.join(__dirname, name), asset })
  tray = new Tray(nativeImage.createFromPath(asset('tray.png')))
  tray.on('click', toggleHub)
  updateTray()

  // UTTER_NO_KEYS skips the global keyboard hook, for UI checks on a machine without it.
  if (!process.env.UTTER_NO_KEYS) {
    try { startKeys() } catch { flash('error', 'Hold-to-talk needs an X11 session', 8000) }
  }
  globalShortcut.register('Control+Alt+Space', () => toggleHandsFree('app'))
  globalShortcut.register('Control+Alt+N', () => toggleHandsFree('note'))
  globalShortcut.register('Control+Alt+U', () => showApp('library'))
  globalShortcut.register('Control+Alt+R', () => toggleHandsFree('memory'))

  startEngine()
  winHelper.ask('focus')
  setInterval(() => { if (ud.offerToTranscribeCalls || meeting?.callApp) watchCalls() }, 3000)
  if (!account && !ud.signInSkipped) showApp('sign-in')
  else if (!ud.hasCompletedOnboarding) showApp('onboarding')
  else if (!process.argv.includes('--hidden')) showApp('library')
})
