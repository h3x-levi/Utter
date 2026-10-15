// CX ArtLab's agent-robot-avatar (what the Mac's RobotView was ported from) plus the Mac port's additions:
// the mic-level caret swell, window dragging, the bubble and the moments in companion-moments.json.
import './vendor/agent-robot-avatar/agent-robot-avatar.js'
import { MomentPlayer, clock, route, timeOfDay } from './companion-player.js'

const PREVIEW = location.hash === '#preview'
const avatar = document.getElementById('avatar')
const robot = document.getElementById('robot')
const bubble = document.getElementById('bubble')
const reduce = matchMedia('(prefers-reduced-motion: reduce)')
const dark = matchMedia('(prefers-color-scheme: dark)')
const shadow = avatar.shadowRoot
const $ = (id) => shadow.getElementById(id)

const ICONS = {
  failure: 'M6 1.2 11.3 10.6H.7zM5.4 4.4v3.3h1.2V4.4zM5.4 8.3v1.2h1.2V8.3z',
  timer: 'M5 .3h2v1H5zM6 1.6a4.75 4.75 0 1 0 0 9.5a4.75 4.75 0 1 0 0-9.5zm0 1.1a3.65 3.65 0 1 1 0 7.3a3.65 3.65 0 1 1 0-7.3zM5.5 3.6h1v3l1.8 1.1-.5.85-2.3-1.4z',
  reminder: 'M6 .8c.4 0 .7.3.7.7v.4a3.5 3.5 0 0 1 2.8 3.4v2.1l1 1.3v.6H1.5v-.6l1-1.3V5.3a3.5 3.5 0 0 1 2.8-3.4v-.4c0-.4.3-.7.7-.7zM4.6 10h2.8a1.4 1.4 0 0 1-2.8 0z',
  pinned: 'M3.5 1h5v1l-.9.6v3l1.9 1.6v.9H6.5V11L6 11.6 5.5 11V8.1H2.5v-.9l1.9-1.6v-3L3.5 2z',
}
const SPOKEN = { failure: 'Dictation failed', timer: 'Focus timer', reminder: 'Reminder', pinned: 'Pinned note' }

const PERSISTS = new Set(['input', 'waiting', 'sleep'])
const IDLE_ONLY = new Set(['ambient', 'near', 'poke', 'fling'])
const NO_REPLAY = new Set(['listening', 'thinking'])
const HOLD = new Set(['listening', 'talking', 'quiet'])
const AMBIENT_AFTER_MS = 12000
const POKE_MS = 140
const POKE_STREAK_MS = 1500

let current = { robotState: 'idle', playToken: -1, quiet: false, notice: null }
let shownToken = -1
let lastQuip = 0
let player = null
let started = false
let seenCue = null
let lastActivity = Date.now()
let pointerNear = false
let poke = { at: -Infinity, count: 0 }
const memory = { at: {}, last: {} }

// ---------- Drawing on top of upstream's frame ----------

let level = 0
let lastLoud = 0

// RobotView.levelChanged: the input caret swells with the voice and stops blinking while it is loud.
function drawLevel(now) {
  const input = avatar._state === 'input' && !reduce.matches
  const swell = input && level >= 0.02 ? level : 0
  for (const id of ['leftInputBase', 'rightInputBase']) {
    const caret = $(id)
    if (!caret) continue
    if (swell) caret.setAttribute('transform', `scale(${(1 + 0.35 * swell).toFixed(3)} ${(1 + 0.1 * swell).toFixed(3)})`)
    else caret.removeAttribute('transform')
    if (input && now - lastLoud < 600) caret.setAttribute('opacity', '1')
  }
}

const baseDraw = avatar._draw.bind(avatar)
avatar._draw = (now) => {
  const result = baseDraw(now)
  drawLevel(now)
  return result
}

// ---------- Moments: cues from main and from this window, gated the same way as CompanionWindow ----------

function syncLook() {
  if (!player) return
  const lib = player.lib
  const look = {
    finish: Object.hasOwn(lib.finishes, current.finish) ? current.finish : lib.defaults.finish,
    worn: Object.hasOwn(lib.accessories, current.worn) && lib.accessories[current.worn].wear ? current.worn : null,
    time: timeOfDay(lib),
    dark: dark.matches,
  }
  if (Object.keys(look).some((k) => look[k] !== player.look[k])) player.setLook(look)
}

function playState(name) {
  lastActivity = Date.now()
  avatar.play(name)
}

function pick(event, detail, fresh) {
  if (!player || current.quiet) return null
  if (IDLE_ONLY.has(event) && (player.current || PERSISTS.has(current.robotState))) return null
  if (NO_REPLAY.has(event) && !fresh) return null
  return route(player.lib, event, { ...clock(player.lib), ...detail }, memory)
}

function perform(id, event) {
  lastActivity = Date.now()
  return player.play(id, { loop: player.lib.moments[id].loopFrom != null, hold: HOLD.has(event) }).then((ended) => {
    lastActivity = Date.now()
    if (ended && PERSISTS.has(current.robotState)) playState(current.robotState)
  })
}

// True when the cue took the robot over, so the upstream state from the same update is not played.
function cue(event, detail = {}, fresh = false) {
  lastActivity = Date.now()
  const id = pick(event, detail, fresh)
  const run = id ? perform(id, event) : Promise.resolve()
  if (event === 'hiding') run.finally(() => utter.companion('bye'))
  return Boolean(id) || event === 'hiding'
}

function tick() {
  syncLook()
  const idle = started && player && !current.quiet && !PERSISTS.has(current.robotState) && !player.current && !avatar._sleeping
  if (idle && Date.now() - lastActivity >= AMBIENT_AFTER_MS) cue('ambient')
}

// ---------- State from main ----------

function layout(state) {
  const side = state.size
  Object.assign(robot.style, { width: `${side}px`, height: `${side}px`, left: `${(innerWidth - side) / 2}px`, top: '64px' })
  avatar.setAttribute('size', String(side))
  avatar.setAttribute('auto-sleep', state.quiet ? '5000' : '30000')
  if (avatar._headRoundness !== state.roundness) avatar.setHeadRoundness?.(state.roundness)
}

function showBubble(state) {
  const notice = state.notice
  const slot = document.querySelector(state.layout?.below ? '.slot.bottom' : '.slot.top')
  for (const s of document.querySelectorAll('.slot')) {
    s.style.paddingLeft = `${state.layout?.leading || 0}px`
    s.style.paddingRight = `${state.layout?.trailing || 0}px`
  }
  if (!notice) {
    if (!bubble.hidden) leave()
    return
  }
  const appearing = bubble.hidden || bubble.parentElement !== slot
  slot.append(bubble)
  bubble.className = notice.kind
  bubble.querySelector('path').setAttribute('d', ICONS[notice.kind])
  bubble.querySelector('path').setAttribute('fill-rule', 'evenodd')
  bubble.querySelector('.line').textContent = notice.line
  bubble.querySelector('.detail').textContent = notice.detail || ''
  bubble.hidden = false
  if (appearing) {
    bubble.getAnimations().forEach((a) => a.cancel())
    bubble.style.transformOrigin = state.layout?.below ? 'center top' : 'center bottom'
    bubble.animate(reduce.matches ? [{ opacity: 0 }, { opacity: 1 }]
      : [{ opacity: 0, transform: 'scale(0.9)' }, { opacity: 1, transform: 'scale(1)' }], { duration: 260, easing: 'cubic-bezier(0.2, 0.9, 0.3, 1)' })
  }
  if (state.quipId && state.quipId !== lastQuip) {
    lastQuip = state.quipId
    document.getElementById('announce').textContent = `${SPOKEN[notice.kind]}: ${notice.line}${notice.detail ? `. ${notice.detail}` : ''}`
  }
}

function leave() {
  const fade = bubble.animate(reduce.matches ? [{ opacity: 1 }, { opacity: 0 }]
    : [{ opacity: 1, transform: 'scale(1)' }, { opacity: 0, transform: 'scale(0.9)' }], { duration: 180, easing: 'ease-in' })
  fade.onfinish = () => { if (!current.notice) bubble.hidden = true }
}

// The first message's cue happened before this window existed, so it is taken as seen and `shown` plays instead.
function apply(state) {
  const fresh = state.playToken !== shownToken
  const incoming = !started ? { event: 'shown' } : state.cue?.id !== seenCue ? state.cue : null
  started = true
  if (state.cue) seenCue = state.cue.id
  current = state
  shownToken = state.playToken
  layout(state)
  showBubble(state)
  syncLook()
  if (incoming && cue(incoming.event, incoming.detail, fresh)) return
  if (!fresh) return
  if (player?.current) player.stop()
  playState(state.robotState)
}

// Pointer positions come from main, because the cursor is usually outside this small window.
function pointer({ x, y }) {
  const r = avatar.getBoundingClientRect()
  const near = 1 - Math.hypot(x - (r.left + r.width / 2), y - (r.top + r.height / 2)) / (Math.max(r.width, r.height) * 2.55) > 0.65
  const rising = near && !pointerNear
  pointerNear = near
  if (player?.current) return
  window.dispatchEvent(new PointerEvent('pointermove', { clientX: x, clientY: y }))
  if (!near) return
  avatar.noteActivity?.(false)
  if (avatar._boredRoutine) avatar.play('idle')
  else if (avatar._sleeping) { if (!current.quiet) playState('wake') }
  else if (rising) cue('near')
}

function onLevel(target) {
  if (avatar._state !== 'input' || reduce.matches) return
  level = target > level ? target : level * 0.8 + target * 0.2
  if (level > 0.08) lastLoud = performance.now()
}

// ---------- Dragging the window; the antenna pull and the squeeze stay the robot's own ----------

let press = null

function onPointerDown(e) {
  if (e.button !== 0) return
  press = { id: e.pointerId, x: e.screenX, y: e.screenY, moving: false, samples: [[e.screenX, e.screenY, e.timeStamp]] }
}

function onPointerMove(e) {
  if (!press && player?.current) e.stopImmediatePropagation()
  if (!press || e.pointerId !== press.id) return
  if (avatar._gestureFx?.kind === 'antenna-drag') return
  if (!press.moving && Math.hypot(e.screenX - press.x, e.screenY - press.y) > 3) {
    press.moving = true
    avatar._onDragEnd?.(new PointerEvent('pointercancel', { pointerId: e.pointerId }))
    try { robot.setPointerCapture(e.pointerId) } catch {}
    utter.companion('drag-start')
  }
  if (!press.moving) return
  e.stopImmediatePropagation()
  lastActivity = Date.now()
  press.samples = [...press.samples, [e.screenX, e.screenY, e.timeStamp]].slice(-4)
  utter.companion('drag')
}

function onPointerUp(e) {
  if (!press || e.pointerId !== press.id) return
  const moving = press.moving
  const samples = press.samples
  press = null
  if (!moving) {
    const tap = e.type === 'pointerup' && e.timeStamp - samples[0][2] <= POKE_MS && robot.contains(e.target)
    if (!tap || avatar._gestureFx?.kind === 'antenna-drag') return
    const now = Date.now()
    poke = { at: now, count: now - poke.at < POKE_STREAK_MS ? poke.count + 1 : 1 }
    cue('poke', { count: poke.count })
    return
  }
  e.stopImmediatePropagation()
  const [first, last] = [samples[0], samples[samples.length - 1]]
  const fresh = e.timeStamp - last[2] < 50 && last[2] > first[2]
  const dt = (last[2] - first[2]) / 1000
  const vx = fresh ? (last[0] - first[0]) / dt : 0
  const vy = fresh ? (last[1] - first[1]) / dt : 0
  utter.companion('drag-end', { vx, vy, reduce: reduce.matches })
  cue('fling', { speed: Math.hypot(vx, vy) })
}

if (PREVIEW) {
  document.body.classList.add('preview')
  avatar.setAttribute('size', '116')
  avatar.setAttribute('auto-sleep', '0')
  window.addEventListener('message', ({ data }) => {
    if (data?.library && !player) player = new MomentPlayer(avatar, data.library)
    if (typeof data?.roundness === 'number') avatar.setHeadRoundness?.(data.roundness)
    if (typeof data?.finish === 'string') current.finish = data.finish
    if (typeof data?.worn === 'string') current.worn = data.worn
    syncLook()
  })
} else {
  window.addEventListener('pointerdown', onPointerDown, true)
  window.addEventListener('pointermove', onPointerMove, true)
  window.addEventListener('pointerup', onPointerUp, true)
  window.addEventListener('pointercancel', onPointerUp, true)
  robot.addEventListener('mouseenter', () => utter.companion('mouse', true))
  robot.addEventListener('mouseleave', () => utter.companion('mouse', false))
  robot.addEventListener('contextmenu', (e) => { e.preventDefault(); utter.companion('menu') })
  const library = await utter.companion('library').catch(() => null)
  if (library) player = new MomentPlayer(avatar, library)
  utter.onCompanion((message) => {
    if (message.type === 'state') apply(message)
    else if (message.type === 'pointer') pointer(message)
    else if (message.type === 'level') onLevel(message.level)
  })
  utter.companion('ready')
}
dark.addEventListener('change', syncLook)
setInterval(tick, 1000)
