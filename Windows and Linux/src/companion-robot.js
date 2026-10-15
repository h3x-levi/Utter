// CX ArtLab's agent-robot-avatar (what the Mac's RobotView was ported from) plus the Mac port's additions:
// the love state, the mic-level caret swell, the dark rim, window dragging and the bubble.
import './vendor/agent-robot-avatar/agent-robot-avatar.js'

const PREVIEW = location.hash === '#preview'
const avatar = document.getElementById('avatar')
const robot = document.getElementById('robot')
const bubble = document.getElementById('bubble')
const reduce = matchMedia('(prefers-reduced-motion: reduce)')
const dark = matchMedia('(prefers-color-scheme: dark)')
const shadow = avatar.shadowRoot
const $ = (id) => shadow.getElementById(id)
const smooth = (t) => { const c = Math.min(1, Math.max(0, t)); return c * c * (3 - 2 * c) }
const lerp = (a, b, t) => a + (b - a) * t

const ICONS = {
  failure: 'M6 1.2 11.3 10.6H.7zM5.4 4.4v3.3h1.2V4.4zM5.4 8.3v1.2h1.2V8.3z',
  timer: 'M5 .3h2v1H5zM6 1.6a4.75 4.75 0 1 0 0 9.5a4.75 4.75 0 1 0 0-9.5zm0 1.1a3.65 3.65 0 1 1 0 7.3a3.65 3.65 0 1 1 0-7.3zM5.5 3.6h1v3l1.8 1.1-.5.85-2.3-1.4z',
  reminder: 'M6 .8c.4 0 .7.3.7.7v.4a3.5 3.5 0 0 1 2.8 3.4v2.1l1 1.3v.6H1.5v-.6l1-1.3V5.3a3.5 3.5 0 0 1 2.8-3.4v-.4c0-.4.3-.7.7-.7zM4.6 10h2.8a1.4 1.4 0 0 1-2.8 0z',
  pinned: 'M3.5 1h5v1l-.9.6v3l1.9 1.6v.9H6.5V11L6 11.6 5.5 11V8.1H2.5v-.9l1.9-1.6v-3L3.5 2z',
}
const SPOKEN = { failure: 'Dictation failed', timer: 'Focus timer', reminder: 'Reminder', pinned: 'Pinned note' }

let current = { robotState: 'idle', playToken: -1, quiet: false, notice: null }
let shownToken = -1
let lastQuip = 0

// ---------- Drawing on top of upstream's frame ----------

let level = 0
let lastLoud = 0
let love = null
let loveTimers = []

function rim() {
  const on = dark.matches
  for (const [el, width] of [[$('head'), 5 / 0.94], [$('antennaDot'), 5]]) {
    if (!el) continue
    if (on) { el.setAttribute('stroke', 'rgba(255, 255, 255, 0.32)'); el.setAttribute('stroke-width', String(width)) }
    else el.removeAttribute('stroke')
  }
}

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

// RobotChoreography.drawLove: the eyes tilt into a heart and beat three times.
function drawLove(now) {
  if (!love) return
  const el = Math.min(2880, Math.max(0, now - love))
  const holdEnd = 240 + 760 * 3
  const reduced = reduce.matches
  const morph = reduced ? 1 : el < 240 ? smooth(el / 240) : el > holdEnd ? 1 - smooth((el - holdEnd) / 360) : 1
  let pulse = 0
  if (!reduced && el >= 240 && el <= holdEnd) {
    const phase = ((el - 240) % 760) / 760
    const swell = (c, w) => Math.max(0, 1 - Math.abs(phase - c) / w)
    pulse = Math.max(smooth(swell(0.12, 0.12)), 0.6 * smooth(swell(0.36, 0.12)))
  }
  const scale = 1 + 0.155 * pulse
  const tilt = 42
  const baseY = 126 + 40 * Math.cos((tilt * Math.PI) / 180)
  for (const [prefix, restX, side] of [['left', 86, -1], ['right', 154, 1]]) {
    const x = 120 + scale * (lerp(restX, 120 - side * 13, morph) - 120)
    const y = 126 + scale * (lerp(126, baseY, morph) - 126)
    $(`${prefix}Eye`).setAttribute('transform', `translate(${x.toFixed(2)} ${y.toFixed(2)}) rotate(${(side * tilt * morph).toFixed(2)}) scale(${scale.toFixed(3)})`)
    const base = $(`${prefix}Base`)
    base.setAttribute('cx', '0')
    base.setAttribute('cy', lerp(0, -40, morph).toFixed(2))
    base.setAttribute('rx', lerp(27, 28, morph).toFixed(2))
    base.setAttribute('ry', lerp(29, 43, morph).toFixed(2))
    base.setAttribute('opacity', '1')
    $(`${prefix}InputBase`).setAttribute('opacity', '0')
    const top = $(`${prefix}Top`)
    const bottom = $(`${prefix}Bottom`)
    top.setAttribute('y', (lerp(-36, -150, morph) - 60).toFixed(2))
    bottom.setAttribute('y', lerp(36, 150, morph).toFixed(2))
    top.removeAttribute('transform')
    bottom.removeAttribute('transform')
  }
}

const baseDraw = avatar._draw.bind(avatar)
avatar._draw = (now) => {
  const result = baseDraw(now)
  drawLevel(now)
  drawLove(now)
  return result
}

function stopLove() {
  loveTimers.forEach(clearTimeout)
  loveTimers = []
  robot.getAnimations().forEach((a) => a.cancel())
  if (love !== null || !avatar._pointerFollowEnabled) avatar.setPointerFollow(true)
  love = null
}

function startLove() {
  avatar.play('idle')
  avatar.setPointerFollow(false)
  loveTimers.push(setTimeout(() => {
    love = performance.now()
    avatar._resumeFrames?.()
    if (!reduce.matches) {
      const unit = robot.clientHeight / 240
      robot.animate([
        { transform: 'translateY(0)', easing: 'cubic-bezier(0.38, 0, 0.25, 1)' },
        { transform: `translateY(${-2 * unit}px)`, offset: 0.3, easing: 'cubic-bezier(0.35, 0, 0.22, 1)' },
        { transform: `translateY(${-unit}px)`, offset: 0.68, easing: 'cubic-bezier(0.35, 0, 0.22, 1)' },
        { transform: 'translateY(0)' },
      ], { duration: 2880 })
    }
    loveTimers.push(setTimeout(stopLove, 2910))
  }, 280))
}

// ---------- State from main ----------

function play(state) {
  if (state.playToken === shownToken) return
  shownToken = state.playToken
  stopLove()
  if (state.robotState === 'love') return startLove()
  avatar.play(state.robotState)
}

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

function apply(state) {
  current = state
  layout(state)
  showBubble(state)
  play(state)
  rim()
}

// Pointer positions come from main, because the cursor is usually outside this small window.
function pointer({ x, y }) {
  window.dispatchEvent(new PointerEvent('pointermove', { clientX: x, clientY: y }))
  const r = avatar.getBoundingClientRect()
  const influence = 1 - Math.hypot(x - (r.left + r.width / 2), y - (r.top + r.height / 2)) / (Math.max(r.width, r.height) * 2.55)
  if (influence <= 0.65) return
  avatar.noteActivity?.()
  if (avatar._boredRoutine) avatar.play('idle')
  else if (avatar._sleeping && !current.quiet) avatar.play('wake')
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
  press.samples = [...press.samples, [e.screenX, e.screenY, e.timeStamp]].slice(-4)
  utter.companion('drag')
}

function onPointerUp(e) {
  if (!press || e.pointerId !== press.id) return
  const moving = press.moving
  const samples = press.samples
  press = null
  if (!moving) return
  e.stopImmediatePropagation()
  const [first, last] = [samples[0], samples[samples.length - 1]]
  const fresh = e.timeStamp - last[2] < 50 && last[2] > first[2]
  const dt = (last[2] - first[2]) / 1000
  utter.companion('drag-end', {
    vx: fresh ? (last[0] - first[0]) / dt : 0, vy: fresh ? (last[1] - first[1]) / dt : 0, reduce: reduce.matches,
  })
}

if (PREVIEW) {
  document.body.classList.add('preview')
  avatar.setAttribute('size', '116')
  avatar.setAttribute('auto-sleep', '0')
  window.addEventListener('message', (e) => {
    if (typeof e.data?.roundness === 'number') avatar.setHeadRoundness?.(e.data.roundness)
  })
  rim()
} else {
  window.addEventListener('pointerdown', onPointerDown, true)
  window.addEventListener('pointermove', onPointerMove, true)
  window.addEventListener('pointerup', onPointerUp, true)
  window.addEventListener('pointercancel', onPointerUp, true)
  robot.addEventListener('mouseenter', () => utter.companion('mouse', true))
  robot.addEventListener('mouseleave', () => utter.companion('mouse', false))
  robot.addEventListener('contextmenu', (e) => { e.preventDefault(); utter.companion('menu') })
  utter.onCompanion((message) => {
    if (message.type === 'state') apply(message)
    else if (message.type === 'pointer') pointer(message)
    else if (message.type === 'level') onLevel(message.level)
  })
  utter.companion('ready')
}
dark.addEventListener('change', rim)
