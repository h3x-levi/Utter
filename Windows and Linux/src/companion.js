// The desktop companion, ported from the Mac app: CompanionWindow, CompanionBehaviour,
// ReminderScheduler, the goal bookkeeping in UserData, and CompanionMemoryStore.
const { BrowserWindow, Menu, Notification, dialog, ipcMain, screen } = require('electron')
const fs = require('node:fs')
const path = require('node:path')
const { randomUUID } = require('node:crypto')
const { execFile } = require('node:child_process')
const chrono = require('chrono-node')

const WIN = process.platform === 'win32'
const SIZES = { small: 32, medium: 40, large: 56, huge: 72 }
const BUBBLE_WIDTH = 220
const BUBBLE_ROOM = 64
const PERSISTS = new Set(['waiting', 'input', 'sleep'])

const DEFAULTS = {
  companionEnabled: false, companionSize: 'medium', companionUserName: '', companionStretchMinutes: 45,
  companionWaterMinutes: 0, companionPomodoroFocusMinutes: 0, companionPomodoroBreakMinutes: 5, companionPinnedMessage: '',
  companionSounds: true, companionMemoryEnabled: true, companionGoalsEnabled: true, companionQuietMode: false,
  companionAutomaticQuietMode: true, companionHydrationGoal: 4, companionStretchGoal: 3, companionFocusGoal: 2,
  companionDictationGoal: 500, companionHeadRoundness: 50,
}
const CLAMPS = {
  companionStretchMinutes: 480, companionWaterMinutes: 480, companionPomodoroFocusMinutes: 480, companionPomodoroBreakMinutes: 480,
  companionHydrationGoal: 20, companionStretchGoal: 20, companionFocusGoal: 20, companionDictationGoal: 10000, companionHeadRoundness: 100,
}

function normalise(ud) {
  for (const [key, value] of Object.entries(DEFAULTS)) {
    if (typeof ud[key] !== typeof value) ud[key] = value
  }
  for (const [key, max] of Object.entries(CLAMPS)) ud[key] = Math.min(max, Math.max(0, Math.round(ud[key])))
  if (!SIZES[ud.companionSize]) ud.companionSize = 'medium'
}

// ---------- Reminders, goals and the day's progress ----------

const dayStamp = (d = new Date()) => d.getFullYear() * 10000 + (d.getMonth() + 1) * 100 + d.getDate()

const reminderLine = (r, name) => {
  const you = name ? `, ${name}` : ''
  if (r.kind === 'stretch') return `Stretch time${you}`
  if (r.kind === 'water') return `Water break${you}`
  if (r.kind === 'pomodoro') return r.focus ? `Break time${you}` : `Back to focus${you}`
  return r.text
}
const memoryKey = (r) => (r.kind === 'pomodoro' ? (r.focus ? 'focus' : 'break') : r.kind)

function progressFor(progress, date = new Date()) {
  const p = { hydration: 0, stretches: 0, focusBlocks: 0, dictationWords: 0, dismissed: {}, preferredHours: {}, extraDelayMinutes: {},
    dictations: 0, memoriesCreated: 0, memoriesCompleted: 0, ...progress }
  if (p.day !== dayStamp(date)) Object.assign(p, { day: dayStamp(date), hydration: 0, stretches: 0, focusBlocks: 0, dictationWords: 0 })
  return p
}

function recordReminder(ud, reminder, completed, date = new Date()) {
  const p = progressFor(ud.companionProgress, date)
  const key = memoryKey(reminder)
  if (ud.companionMemoryEnabled) {
    if (completed) p.preferredHours = { ...p.preferredHours, [key]: date.getHours() }
    else {
      p.dismissed = { ...p.dismissed, [key]: (p.dismissed[key] || 0) + 1 }
      p.extraDelayMinutes = { ...p.extraDelayMinutes, [key]: Math.min(30, (p.extraDelayMinutes[key] || 0) + 5) }
    }
  }
  let celebration = null
  if (completed && ud.companionGoalsEnabled) {
    if (reminder.kind === 'water' && ++p.hydration === ud.companionHydrationGoal && ud.companionHydrationGoal > 0) celebration = 'Hydration goal complete'
    if (reminder.kind === 'stretch' && ++p.stretches === ud.companionStretchGoal && ud.companionStretchGoal > 0) celebration = 'Stretch goal complete'
    if (reminder.kind === 'pomodoro' && reminder.focus && ++p.focusBlocks === ud.companionFocusGoal && ud.companionFocusGoal > 0) celebration = 'Focus goal complete'
  }
  ud.companionProgress = p
  return celebration
}

// Main has already added the words to today's progress when it signals 'delivered'.
function dictationGoalReached(ud, words) {
  const p = ud.companionProgress
  const goal = ud.companionDictationGoal
  if (!ud.companionGoalsEnabled || goal <= 0 || !p || p.day !== dayStamp()) return false
  return p.dictationWords - words < goal && p.dictationWords >= goal
}

const extraDelay = (ud, reminder) => (ud.companionMemoryEnabled ? ud.companionProgress?.extraDelayMinutes?.[memoryKey(reminder)] || 0 : 0)

class ReminderScheduler {
  constructor() {
    this.stretchEvery = this.waterEvery = this.pomodoroFocus = this.pomodoroBreak = null
    this.lastStretch = this.lastWater = this.pomodoroStartedAt = null
    this.pomodoroInFocus = true
  }

  begin(now) {
    this.lastStretch = this.lastWater = now
    if (this.pomodoroStartedAt == null) this.pomodoroStartedAt = now
  }

  due(now) {
    if (this.pomodoroFocus && this.pomodoroBreak && this.pomodoroStartedAt != null) {
      const length = this.pomodoroInFocus ? this.pomodoroFocus : this.pomodoroBreak
      if (now - this.pomodoroStartedAt >= length) {
        const finished = this.pomodoroInFocus
        this.pomodoroInFocus = !this.pomodoroInFocus
        this.pomodoroStartedAt = now
        return { kind: 'pomodoro', focus: finished }
      }
    }
    if (this.stretchEvery && this.lastStretch != null && now - this.lastStretch >= this.stretchEvery) {
      this.lastStretch = now
      return { kind: 'stretch' }
    }
    if (this.waterEvery && this.lastWater != null && now - this.lastWater >= this.waterEvery) {
      this.lastWater = now
      return { kind: 'water' }
    }
    return null
  }

  pomodoroRemaining(now) {
    if (!this.pomodoroFocus || !this.pomodoroBreak || this.pomodoroStartedAt == null) return null
    return Math.max(0, (this.pomodoroInFocus ? this.pomodoroFocus : this.pomodoroBreak) - (now - this.pomodoroStartedAt))
  }
}

const countdown = (ms) => {
  const whole = Math.round(ms / 1000)
  return `${Math.floor(whole / 60)}:${String(whole % 60).padStart(2, '0')}`
}

// ---------- Behaviour: what the robot shows, as values ----------

class Behaviour {
  constructor(onChange) {
    this.onChange = onChange
    this.robotState = 'idle'
    this.playToken = 0
    this.quiet = false
    this.quip = null
    this.quipGeneration = 0
    this.currentReminder = null
    this.countdown = null
    this.pinned = ''
    this.reachedProcessing = false
  }

  get notice() {
    const detail = this.pinned.trim() || null
    if (this.quip) return { ...this.quip, detail }
    if (this.countdown) return { kind: 'timer', line: this.countdown, detail }
    return detail ? { kind: 'pinned', line: detail, detail: null } : null
  }

  apply(event, detail = {}) {
    if (this.quiet) return
    if (event === 'listening') { this.reachedProcessing = false; this.show('input') }
    else if (event === 'thinking') { this.reachedProcessing = true; this.show('waiting') }
    else if (event === 'error') {
      this.reachedProcessing = false
      this.show('failure')
      this.say({ kind: 'failure', line: detail.message || 'Something went wrong' }, 5)
    } else if (event === 'island') {
      this.reachedProcessing = false
      if (PERSISTS.has(this.robotState)) this.show('idle')
    } else if (event === 'done' || event === 'notice' || event === 'idle') {
      if (this.reachedProcessing) this.show('success')
      else if (PERSISTS.has(this.robotState)) this.show('idle')
      this.reachedProcessing = false
    }
  }

  announce(reminder, name) {
    if (this.quiet) return
    this.currentReminder = reminder
    this.show('send')
    this.say({ kind: 'reminder', line: reminderLine(reminder, name) }, 8)
  }

  celebrate(line) {
    if (this.quiet) return
    this.show('love')
    this.say({ kind: 'reminder', line }, 5)
  }

  respond(completed) {
    const reminder = this.currentReminder
    if (!reminder) return null
    this.currentReminder = null
    this.quip = null
    if (completed) this.show('success')
    else this.onChange()
    return reminder
  }

  setQuiet(on) {
    if (on === this.quiet) return
    this.quiet = on
    this.robotState = on ? 'sleep' : 'wake'
    this.playToken++
    this.reachedProcessing = false
    if (on) { this.currentReminder = null; this.quip = null }
    this.onChange()
  }

  setCountdown(ms) {
    const text = ms > 0 ? countdown(ms) : null
    if (text === this.countdown) return
    this.countdown = text
    this.onChange()
  }

  // Persistent states are not replayed when unchanged; one-shots always replay.
  show(state) {
    if (this.quiet || (state === this.robotState && (PERSISTS.has(state) || state === 'idle'))) return
    this.robotState = state
    this.playToken++
    this.onChange()
  }

  say(notice, seconds) {
    this.quip = notice
    const generation = ++this.quipGeneration
    this.onChange()
    setTimeout(() => {
      if (generation !== this.quipGeneration) return
      this.quip = null
      this.onChange()
    }, seconds * 1000)
  }
}

// ---------- Private memories (companion-memories.json, the Mac's shape) ----------

const COMMAND_PREFIXES = ['remind me to ', 'remind me that ', 'remember to ', 'remember that ', 'remember ', 'please remind me to ',
  'please remember to ', 'please remember that ', 'please remember ']

function stripCommandWords(input) {
  let text = input.trim()
  const prefix = COMMAND_PREFIXES.find((p) => text.toLowerCase().startsWith(p))
  if (prefix) text = text.slice(prefix.length)
  return text.replace(/^[\s,.-]+|[\s,.-]+$/g, '')
}

function validated(input) {
  const text = String(input || '').trim()
  if (!text) throw new Error('Write what you want Utter to remember.')
  if (Array.from(text).length > 1000) throw new Error('A memory can be at most 1,000 characters.')
  return text
}

// The Mac falls back to NSDataDetector when Apple Intelligence is off; chrono-node does that job here.
function parseMemory(input, now = new Date()) {
  const cleaned = validated(input)
  const match = chrono.parse(cleaned, now, { forwardDate: true }).find((r) => r.start.date() > now)
  let text = cleaned
  let remindAt = null
  if (match) {
    remindAt = match.start.date()
    text = cleaned.slice(0, match.index) + cleaned.slice(match.index + match.text.length)
  }
  text = stripCommandWords(text.replace(/\s{2,}/g, ' ')) || stripCommandWords(cleaned)
  return { text, remindAt }
}

class MemoryStore {
  constructor(dir, { onCreated, onCompleted, onChange }) {
    this.file = path.join(dir, 'companion-memories.json')
    this.previous = path.join(dir, 'companion-memories.previous.json')
    this.dir = dir
    Object.assign(this, { onCreated, onCompleted, onChange })
    this.memories = this.load()
  }

  load() {
    const decode = (raw) => {
      const list = JSON.parse(raw)
      if (!Array.isArray(list)) throw new Error('not a list')
      return list.map((m) => ({ ...m, ...Object.fromEntries(['createdAt', 'remindAt', 'deliveredAt', 'completedAt']
        .filter((k) => typeof m[k] === 'number').map((k) => [k, m[k] > 1e11 ? m[k] / 1000 : m[k]])) }))
    }
    let raw
    try { raw = fs.readFileSync(this.file, 'utf8') } catch { return [] }
    try { return decode(raw) } catch {}
    let recovered = []
    try { recovered = decode(fs.readFileSync(this.previous, 'utf8')) } catch {}
    try { fs.renameSync(this.file, path.join(this.dir, `companion-memories-unreadable-${Math.floor(Date.now() / 1000)}.json`)) } catch {}
    if (recovered.length) this.persist(recovered)
    return recovered
  }

  persist(list = this.memories) {
    const sorted = list.map((m) => Object.fromEntries(Object.keys(m).sort().filter((k) => m[k] != null).map((k) => [k, m[k]])))
    const data = JSON.stringify(sorted, null, 2)
    try {
      const existing = fs.readFileSync(this.file, 'utf8')
      if (existing !== data) fs.writeFileSync(this.previous, existing, { mode: 0o600 })
    } catch {}
    fs.writeFileSync(this.file + '.tmp', data, { mode: 0o600 })
    fs.renameSync(this.file + '.tmp', this.file)
  }

  get active() {
    return this.memories.filter((m) => !m.completedAt).sort((a, b) => {
      if (a.remindAt && b.remindAt) return a.remindAt - b.remindAt
      if (a.remindAt) return -1
      if (b.remindAt) return 1
      return b.createdAt - a.createdAt
    })
  }

  get completed() {
    return this.memories.filter((m) => m.completedAt).sort((a, b) => b.completedAt - a.completedAt)
  }

  add({ text, remindAt }, source, now = new Date()) {
    const clean = validated(text)
    if (remindAt && remindAt <= now) throw new Error('Choose a reminder time in the future.')
    const memory = { id: randomUUID().toUpperCase(), text: clean, createdAt: now.getTime() / 1000, source,
      ...(remindAt && { remindAt: remindAt.getTime() / 1000 }) }
    this.memories.unshift(memory)
    try { this.persist() } catch (error) {
      this.memories.shift()
      throw new Error(`The memory could not be saved: ${error.message}`)
    }
    this.onCreated()
    this.onChange()
    return memory
  }

  update(id, changes) {
    const memory = this.memories.find((m) => m.id === id)
    if (!memory) return
    Object.assign(memory, changes)
    this.persist()
    this.onChange()
    return memory
  }

  complete(id, at = new Date()) {
    const memory = this.memories.find((m) => m.id === id)
    if (!memory || memory.completedAt) return
    this.update(id, { completedAt: at.getTime() / 1000 })
    this.onCompleted()
  }

  delete(id) {
    this.memories = this.memories.filter((m) => m.id !== id)
    this.persist()
    this.onChange()
  }

  deleteAll() {
    this.memories = []
    this.persist()
    this.onChange()
  }
}

// ---------- Panel geometry (CompanionGeometry) ----------

function geometry(size) {
  const robotSide = SIZES[size] * (240 / 213)
  const width = Math.ceil(Math.max(BUBBLE_WIDTH, robotSide))
  const height = Math.ceil(robotSide + BUBBLE_ROOM * 2)
  return { robotSide, width, height, robot: { x: (width - robotSide) / 2, y: BUBBLE_ROOM, side: robotSide } }
}

// Moves the panel as little as possible to keep the robot itself on screen; the empty panel may hang off.
function clampOrigin(g, origin, work) {
  const rx = origin.x + g.robot.x
  const ry = origin.y + g.robot.y
  const x = Math.min(Math.max(rx, work.x), Math.max(work.x, work.x + work.width - g.robotSide))
  const y = Math.min(Math.max(ry, work.y), Math.max(work.y, work.y + work.height - g.robotSide))
  return { x: Math.round(origin.x + (x - rx)), y: Math.round(origin.y + (y - ry)) }
}

function bubbleLayout(g, origin, work) {
  return {
    below: origin.y + g.robot.y - BUBBLE_ROOM < work.y,
    leading: Math.max(0, work.x - origin.x),
    trailing: Math.max(0, origin.x + g.width - (work.x + work.width)),
  }
}

// ---------- The window ----------

let opts = null
let ud = null
let win = null
let geo = null
let behaviour = null
let store = null
let reminders = new ReminderScheduler()
let heartbeat = null
let pointerTimer = null
let pointerNear = false
let screenSharing = false
let lastShareCheck = 0
let meetingRecording = false
let grab = null
let glide = null
let mouseOver = false
let memoryTimer = null
let lastLevelSent = 0

const work = () => screen.getDisplayMatching(win?.getBounds() || screen.getPrimaryDisplay().bounds).workArea

function send(message) {
  if (win && !win.isDestroyed()) win.webContents.send('companion:state', message)
}

function sendState() {
  if (!win || win.isDestroyed()) return
  const origin = win.getBounds()
  send({ type: 'state', robotState: behaviour.robotState, playToken: behaviour.playToken, quiet: behaviour.quiet,
    notice: behaviour.notice, quipId: behaviour.quip ? behaviour.quipGeneration : 0, size: geo.robotSide, roundness: ud.companionHeadRoundness, layout: bubbleLayout(geo, origin, work()) })
  applyShape()
}

// Windows and macOS forward mouse moves to a click-through window; Linux gets an input shape instead.
function applyShape() {
  if (WIN || process.platform === 'darwin') {
    win.setIgnoreMouseEvents(!(mouseOver || grab), { forward: true })
    return
  }
  const r = geo.robot
  const inset = r.side * 0.08
  win.setShape([{ x: Math.round(r.x + inset), y: Math.round(r.y), width: Math.round(r.side - inset * 2), height: Math.round(r.side) },
    ...(behaviour.notice ? [{ x: 0, y: bubbleLayout(geo, win.getBounds(), work()).below ? Math.round(r.y + r.side) : 0, width: geo.width, height: BUBBLE_ROOM }] : [])])
}

// First placement: on the pill's line, clear of the transcript island (360 wide).
function placeBesidePill() {
  const area = screen.getPrimaryDisplay().workArea
  const y = area.y + area.height - 28
  const reach = 360 / 2 + 16 + geo.robotSide / 2
  const centreX = area.x + area.width / 2
  const fitsRight = centreX + reach + geo.robotSide / 2 <= area.x + area.width
  const cx = fitsRight ? centreX + reach : centreX - reach
  return clampOrigin(geo, { x: cx - geo.width / 2, y: y - geo.height / 2 }, area)
}

function restoreOrigin() {
  const saved = ud.companionWindowPosition
  if (!saved || typeof saved.fx !== 'number' || typeof saved.fy !== 'number') return placeBesidePill()
  const display = screen.getAllDisplays().find((d) => d.id === saved.display) || screen.getPrimaryDisplay()
  const area = display.workArea
  const centre = { x: area.x + saved.fx * area.width, y: area.y + saved.fy * area.height }
  return clampOrigin(geo, { x: centre.x - geo.width / 2, y: centre.y - geo.height / 2 }, area)
}

function savePosition() {
  const b = win.getBounds()
  const centre = { x: b.x + b.width / 2, y: b.y + b.height / 2 }
  const display = screen.getDisplayNearestPoint({ x: Math.round(centre.x), y: Math.round(centre.y) })
  const area = display.workArea
  ud.companionWindowPosition = { fx: (centre.x - area.x) / Math.max(area.width, 1), fy: (centre.y - area.y) / Math.max(area.height, 1), display: display.id }
  opts.saveUserdata()
}

function moveTo(origin) {
  win.setBounds({ ...origin, width: geo.width, height: geo.height })
}

function show() {
  if (win && !win.isDestroyed()) return
  geo = geometry(ud.companionSize)
  const origin = restoreOrigin()
  win = new BrowserWindow({
    ...origin, width: geo.width, height: geo.height, show: false, frame: false, transparent: true, resizable: false,
    movable: false, focusable: false, skipTaskbar: true, alwaysOnTop: true, hasShadow: false, backgroundColor: '#00000000',
    ...(WIN && { type: 'toolbar' }),
    webPreferences: { preload: opts.preload, sandbox: true },
  })
  win.setAlwaysOnTop(true, 'screen-saver')
  win.setVisibleOnAllWorkspaces(true)
  win.webContents.on('did-finish-load', () => { win.showInactive(); sendState() })
  win.on('closed', () => { win = null })
  win.loadFile(opts.page('companion.html'))
  reminders = new ReminderScheduler()
  reminders.begin(Date.now())
  heartbeat = setInterval(beat, 1000)
  pointerTimer = setInterval(watchPointer, 50)
}

function hide() {
  clearInterval(heartbeat)
  clearInterval(pointerTimer)
  clearInterval(glide)
  heartbeat = pointerTimer = glide = null
  if (win && !win.isDestroyed()) win.destroy()
  win = null
}

function resize() {
  if (!win) return
  const b = win.getBounds()
  const centre = { x: b.x + b.width / 2, y: b.y + b.height / 2 }
  geo = geometry(ud.companionSize)
  moveTo(clampOrigin(geo, { x: centre.x - geo.width / 2, y: centre.y - geo.height / 2 }, work()))
  sendState()
}

// Once a second: reminder clocks, the focus countdown and automatic quiet.
function beat() {
  const every = (minutes, reminder) => (minutes > 0 ? (minutes + extraDelay(ud, reminder)) * 60000 : null)
  reminders.stretchEvery = every(ud.companionStretchMinutes, { kind: 'stretch' })
  reminders.waterEvery = every(ud.companionWaterMinutes, { kind: 'water' })
  reminders.pomodoroFocus = ud.companionPomodoroFocusMinutes > 0 ? ud.companionPomodoroFocusMinutes * 60000 : null
  reminders.pomodoroBreak = ud.companionPomodoroBreakMinutes > 0 ? ud.companionPomodoroBreakMinutes * 60000 : null
  if (ud.companionAutomaticQuietMode && Date.now() - lastShareCheck > 10000) checkScreenSharing()
  behaviour.pinned = ud.companionPinnedMessage
  behaviour.setQuiet(ud.companionQuietMode || (ud.companionAutomaticQuietMode && (screenSharing || meetingRecording)))
  const now = Date.now()
  behaviour.setCountdown(reminders.pomodoroRemaining(now))
  const due = reminders.due(now)
  if (due) behaviour.announce(due, ud.companionUserName)
}

function checkScreenSharing() {
  lastShareCheck = Date.now()
  const [cmd, args] = WIN ? ['tasklist', ['/fo', 'csv', '/nh']] : ['ps', ['-A', '-o', 'comm=']]
  execFile(cmd, args, { timeout: 5000, windowsHide: true }, (_error, stdout) => {
    const names = String(stdout || '').toLowerCase()
    screenSharing = ['screen sharing', 'cpt host', 'cpthost', 'webex share', 'slideshow'].some((n) => names.includes(n))
  })
}

// Pointer follow and waking need the cursor near the robot, which is mostly outside this small window.
function watchPointer() {
  if (!win || grab) return
  const cursor = screen.getCursorScreenPoint()
  const b = win.getBounds()
  const x = cursor.x - b.x
  const y = cursor.y - b.y
  const dist = Math.hypot(x - (geo.robot.x + geo.robotSide / 2), y - (geo.robot.y + geo.robotSide / 2))
  const near = dist < geo.robotSide * 2.6
  if (near || pointerNear) send({ type: 'pointer', x, y })
  pointerNear = near
}

function glideTo(target) {
  clearInterval(glide)
  const from = win.getBounds()
  const start = Date.now()
  const ease = (t) => {
    // cubic-bezier(0.2, 0.9, 0.3, 1), solved by bisection like RobotEase.bezier
    let lo = 0
    let hi = 1
    const b = (s, a, z) => 3 * (1 - s) * (1 - s) * s * a + 3 * (1 - s) * s * s * z + s * s * s
    for (let i = 0; i < 24; i++) { const mid = (lo + hi) / 2; if (b(mid, 0.2, 0.3) < t) lo = mid; else hi = mid }
    return b((lo + hi) / 2, 0.9, 1)
  }
  glide = setInterval(() => {
    const t = Math.min(1, (Date.now() - start) / 350)
    const k = ease(t)
    moveTo({ x: Math.round(from.x + (target.x - from.x) * k), y: Math.round(from.y + (target.y - from.y) * k) })
    if (t < 1) return
    clearInterval(glide)
    glide = null
    savePosition()
    sendState()
  }, 16)
}

function menu() {
  const items = []
  if (behaviour.currentReminder) {
    items.push({ label: 'Done', click: () => respond(true) }, { label: 'Not Now', click: () => respond(false) }, { type: 'separator' })
  }
  items.push(
    { label: 'Reset Position', click: () => { delete ud.companionWindowPosition; opts.saveUserdata(); moveTo(placeBesidePill()); sendState() } },
    { type: 'separator' },
    { label: 'Companion Settings…', click: () => opts.showApp('companion') },
    { label: 'Hide Companion', click: () => { ud.companionEnabled = false; opts.saveUserdata(); hide(); opts.changed() } },
  )
  Menu.buildFromTemplate(items).popup({ window: win })
}

function respond(completed) {
  const reminder = behaviour.respond(completed)
  if (!reminder) return
  const celebration = recordReminder(ud, reminder, completed)
  opts.saveUserdata()
  opts.changed()
  if (celebration) behaviour.celebrate(celebration)
}

async function robotCommand(command, arg) {
  if (command === 'mouse') { mouseOver = Boolean(arg); applyShape() }
  else if (command === 'drag-start') {
    clearInterval(glide)
    const cursor = screen.getCursorScreenPoint()
    const b = win.getBounds()
    grab = { dx: cursor.x - b.x, dy: cursor.y - b.y }
    applyShape()
  } else if (command === 'drag' && grab) {
    const cursor = screen.getCursorScreenPoint()
    moveTo(clampOrigin(geo, { x: cursor.x - grab.dx, y: cursor.y - grab.dy }, work()))
  } else if (command === 'drag-end' && grab) {
    grab = null
    const { vx = 0, vy = 0, reduce = false } = arg || {}
    const b = win.getBounds()
    if (Math.hypot(vx, vy) > 300 && !reduce) glideTo(clampOrigin(geo, { x: b.x + vx * 0.099, y: b.y + vy * 0.099 }, work()))
    else { savePosition(); sendState() }
  } else if (command === 'menu') menu()
  else if (command === 'ready') sendState()
}

// ---------- Memory reminders: a system notification at the time the user asked for ----------

function scheduleMemories() {
  clearTimeout(memoryTimer)
  const pending = store.active.filter((m) => m.remindAt && !m.deliveredAt)
  if (!pending.length) return
  const next = Math.min(...pending.map((m) => m.remindAt * 1000))
  memoryTimer = setTimeout(deliverMemories, Math.min(Math.max(0, next - Date.now()), 2 ** 31 - 1))
}

function deliverMemories() {
  const now = Date.now() / 1000
  for (const memory of store.active.filter((m) => m.remindAt && !m.deliveredAt && m.remindAt <= now)) {
    store.update(memory.id, { deliveredAt: now })
    if (Notification.isSupported()) {
      const note = new Notification({ title: 'Utter reminder', body: memory.text, silent: !(ud.companionSounds && ud.soundsEnabled !== false) })
      note.on('click', () => opts.showApp('companion'))
      note.show()
    }
  }
  scheduleMemories()
}

function notificationMessage() {
  return Notification.isSupported()
    ? 'Reminders appear while Utter is running.'
    : 'Notifications are unavailable, so reminders appear only in this list.'
}

// ---------- The hooks main calls ----------

module.exports = {
  init(options) {
    opts = options
    ud = options.ud
    normalise(ud)
    behaviour = new Behaviour(sendState)
    behaviour.pinned = ud.companionPinnedMessage
    store = new MemoryStore(options.dataDir, {
      onCreated: () => { ud.companionProgress = { ...progressFor(ud.companionProgress), memoriesCreated: (ud.companionProgress?.memoriesCreated || 0) + 1 }; options.saveUserdata() },
      onCompleted: () => { ud.companionProgress = { ...progressFor(ud.companionProgress), memoriesCompleted: (ud.companionProgress?.memoriesCompleted || 0) + 1 }; options.saveUserdata() },
      onChange: () => { scheduleMemories(); options.changed() },
    })
    scheduleMemories()
    ipcMain.handle('companion', async (_e, command, ...args) => {
      if (['mouse', 'drag-start', 'drag', 'drag-end', 'menu', 'ready'].includes(command)) return robotCommand(command, args[0])
      if (command === 'complete') return store.complete(args[0])
      if (command === 'delete') return store.delete(args[0])
      if (command === 'deleteAll') {
        const { response } = await dialog.showMessageBox({
          type: 'warning', buttons: ['Delete All', 'Cancel'], defaultId: 1, cancelId: 1, message: 'Delete all private reminders?',
          detail: 'This removes every saved reminder and memory, and cancels its notification.',
        })
        if (response === 0) store.deleteAll()
      }
    })
    if (ud.companionEnabled) show()
  },

  signal(event, detail = {}) {
    if (event === 'meeting') meetingRecording = detail.state === 'recording'
    if (event === 'level') {
      if (behaviour?.robotState !== 'input' || Date.now() - lastLevelSent < 33) return
      lastLevelSent = Date.now()
      return send({ type: 'level', level: detail.level })
    }
    if (event === 'delivered' && dictationGoalReached(ud, detail.words || 0)) {
      behaviour?.celebrate('Dictation goal complete')
      return
    }
    behaviour?.apply(event, detail)
  },

  view() {
    if (!store) return null
    const p = progressFor(ud.companionProgress)
    return { active: store.active, completed: store.completed, waiting: store.active.length, notifications: notificationMessage(),
      today: { hydration: p.hydration, stretches: p.stretches, focusBlocks: p.focusBlocks, dictationWords: p.dictationWords } }
  },

  async remember(input) {
    try {
      const proposal = parseMemory(input)
      store.add(proposal, 'spoken')
      const words = proposal.text.split(/\s+/).filter(Boolean).length
      const p = progressFor(ud.companionProgress)
      p.dictationWords += words
      p.dictations += 1
      ud.companionProgress = p
      opts.saveUserdata()
      return { message: proposal.remindAt ? 'Reminder saved' : 'Remembered' }
    } catch (error) {
      return { message: error.message }
    }
  },

  settingChanged(key) {
    normalise(ud)
    if (key === 'companionEnabled') return ud.companionEnabled ? show() : hide()
    if (key === 'companionSize') return resize()
    if (key === 'companionPinnedMessage') behaviour.pinned = ud.companionPinnedMessage
    if (key === 'companionQuietMode' || key === 'companionAutomaticQuietMode') beat()
    sendState()
  },

  quit() {
    hide()
    clearTimeout(memoryTimer)
  },

  // For companion.test.js.
  _test: { reminderLine, progressFor, recordReminder, dictationGoalReached, ReminderScheduler, Behaviour, parseMemory, stripCommandWords,
    MemoryStore, geometry, clampOrigin, bubbleLayout, countdown, normalise },
}
