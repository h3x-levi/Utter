// Plays companion-moments.json on CX ArtLab's agent-robot-avatar without new action names: upstream runtime
// rejects names it does not know, so moments drive poses, #headMotion and gaze directly and draw through a hook.
import { registerAvatarExtension } from './vendor/agent-robot-avatar/src/agent-robot-avatar-extension-host.js'

const NS = 'http://www.w3.org/2000/svg'
const EASE = {
  out: (t) => 1 - (1 - t) ** 5,
  inOut: (t) => (t < 0.5 ? 4 * t ** 3 : 1 - (-2 * t + 2) ** 3 / 2),
  linear: (t) => t,
}
const CURVE = { out: 'cubic-bezier(.16,1,.3,1)', inOut: 'cubic-bezier(.65,0,.35,1)', linear: 'linear', back: 'cubic-bezier(.34,1.56,.64,1)' }
const ENTER = {
  pop: [[{ transform: 'scale(0.4)', opacity: 0 }, { transform: 'scale(1)', opacity: 1 }], 280, CURVE.back],
  drop: [[{ transform: 'translateY(-26px)', opacity: 0 }, { transform: 'translateY(0px)', opacity: 1 }], 360, CURVE.back],
  rise: [[{ transform: 'translateY(18px)', opacity: 0 }, { transform: 'translateY(0px)', opacity: 1 }], 320, CURVE.out],
  fade: [[{ opacity: 0 }, { opacity: 1 }], 260, CURVE.out],
}
const EXIT = {
  pop: [[{ transform: 'scale(1)', opacity: 1 }, { transform: 'scale(0.6)', opacity: 0 }], 180],
  lift: [[{ transform: 'translateY(0px)', opacity: 1 }, { transform: 'translateY(-34px)', opacity: 0 }], 420],
  fade: [[{ opacity: 1 }, { opacity: 0 }], 200],
}
const RIM = { dark: 'rgba(255, 255, 255, 0.32)', light: 'rgba(28, 42, 94, 0.3)' }

export const accessoriesOf = (moment) => [...new Set(moment.steps.filter((s) => s.on).map((s) => s.on))]

export function timeOfDay(library, date = new Date()) {
  const h = date.getHours()
  return Object.keys(library.times).find((id) => {
    const { from, to } = library.times[id]
    return from < to ? h >= from && h < to : h >= from || h < to
  })
}

export const clock = (library, date = new Date()) => ({
  time: timeOfDay(library, date), hour: date.getHours(), weekday: date.getDay(), month: date.getMonth() + 1, day: date.getDate(),
})

// memory is keyed by route index: when it last fired (cooldowns) and what it picked (pools never repeat).
export function route(library, signal, detail = {}, memory = { at: {}, last: {} }, now = Date.now(), random = Math.random) {
  for (const [i, r] of library.routes.entries()) {
    if (r.signal !== signal) continue
    if (r.is && !Object.entries(r.is).every(([k, v]) => (Array.isArray(v) ? v.includes(detail[k]) : detail[k] === v))) continue
    if (r.atLeast && !Object.entries(r.atLeast).every(([k, v]) => detail[k] >= v)) continue
    if (r.every && !(Math.floor(detail.total / r.every) > Math.floor((detail.total - detail.words) / r.every))) continue
    if (r.cooldown && now - (memory.at[i] ?? -Infinity) < r.cooldown) continue
    const pool = r.moments ?? [r.moment]
    const choices = pool.length > 1 ? pool.filter((id) => id !== memory.last[i]) : pool
    const id = choices[Math.floor(random() * choices.length)]
    memory.at[i] = now
    memory.last[i] = id
    return id
  }
  return null
}

registerAvatarExtension({
  name: 'utter-moments',
  beforePlay() {
    if (this._moments && !this._moments.internal) this._moments.stop(true)
  },
  draw(now) {
    this._moments?.draw(now)
  },
})

export class MomentPlayer {
  constructor(avatar, library) {
    this.avatar = avatar
    this.lib = library
    this.look = { finish: library.defaults.finish, time: library.defaults.time, worn: null, dark: false }
    this.shown = new Map()
    this.waits = new Map()
    this.anims = []
    this.token = 0
    this.current = null
    this.internal = false
    this.blinkSeen = 0
    this.rimPending = true
    const root = avatar.shadowRoot
    const $ = (id) => root.getElementById(id)
    const layer = (id) => Object.assign(document.createElementNS(NS, 'g'), { id })
    this.layers = { behind: layer('uBehind'), finish: layer('uFinish'), head: layer('uHead'), front: layer('uFront') }
    this.layers.finish.setAttribute('clip-path', 'url(#headClip)')
    root.querySelector('svg').insertBefore(this.layers.behind, $('dragMotion'))
    $('head').after(this.layers.finish)
    $('headMotion').append(this.layers.head)
    $('dragMotion').after(this.layers.front)
    this.eyes = ['leftBase', 'rightBase', 'leftInputBase', 'rightInputBase'].map($)
    avatar._moments = this
    this.setLook({})
  }

  get finish() { return this.lib.finishes[this.look.finish] }
  get time() { return this.lib.times[this.look.time] }
  get reduced() { return this.avatar._isReducedMotion?.() ?? false }

  setLook(change) {
    Object.assign(this.look, change)
    const f = this.finish
    this.avatar.setAttribute('color', f.body)
    for (const eye of this.eyes) eye.setAttribute('fill', f.eyes)
    this.layers.finish.replaceChildren()
    for (const shape of f.shapes || []) this.render(shape, this.layers.finish, [])
    this.rimPending = true
    this.recolor(this.avatar.shadowRoot)
    this.syncWorn(false)
    this.avatar._resumeFrames?.()
  }

  colour(token) {
    if (token === 'body') return this.finish.body
    if (token === 'eyes') return this.finish.eyes
    const swatch = this.lib.palette[this.finish.swap?.[token] ?? token]
    return swatch ? swatch[this.look.dark ? 1 : 0] : token
  }

  recolor(root) {
    for (const el of root.querySelectorAll('[data-fill], [data-stroke]')) {
      if (el.dataset.fill) el.setAttribute('fill', this.colour(el.dataset.fill))
      if (el.dataset.stroke) el.setAttribute('stroke', this.colour(el.dataset.stroke))
    }
  }

  render(spec, parent, loops) {
    const el = document.createElementNS(NS, spec.el)
    for (const [key, value] of Object.entries(spec)) {
      if (key === 'el' || key === 'kids' || key === 'anim') continue
      if ((key === 'fill' || key === 'stroke') && value !== 'none' && !value.startsWith('#')) el.dataset[key] = value
      else el.setAttribute(key, value)
    }
    if (spec.anim) loops.push({ el, anim: spec.anim })
    for (const kid of spec.kids || []) this.render(kid, el, loops)
    parent.append(el)
    return el
  }

  applyRim() {
    const dot = this.avatar._antennaDot
    const mode = this.finish.outline === (this.look.dark ? 'dark' : 'light') ? (this.look.dark ? 'dark' : 'light') : null
    for (const [el, width] of [[this.avatar._head, 5 / 0.94], [dot, 5]]) {
      if (!el) continue
      if (mode) { el.setAttribute('stroke', RIM[mode]); el.setAttribute('stroke-width', String(width)) }
      else el.removeAttribute('stroke')
    }
    this.rimPending = !dot
  }

  // ---------- Accessories: static SVG; loops are WAAPI and only run while a moment plays ----------

  show(id, enter = true) {
    if (this.shown.has(id)) return
    const spec = this.lib.accessories[id]
    for (const other of [...this.shown.keys()]) if (this.lib.accessories[other].slot === spec.slot) this.hide(other, true)
    const g = document.createElementNS(NS, 'g')
    g.dataset.acc = id
    const loops = []
    for (const shape of spec.shapes) this.render(shape, g, loops)
    this.layers[spec.layer].append(g)
    this.recolor(g)
    this.shown.set(id, { g, loops, running: [] })
    if (enter && !this.reduced) {
      const [frames, ms, easing] = ENTER[spec.enter] || ENTER.pop
      g.style.transformBox = 'fill-box'
      g.style.transformOrigin = '50% 50%'
      g.animate(frames, { duration: ms, easing })
    }
  }

  hide(id, instant = false, exit) {
    const item = this.shown.get(id)
    if (!item) return
    this.shown.delete(id)
    this.stopLoops(item)
    if (instant || this.reduced) return item.g.remove()
    const [frames, ms] = EXIT[exit] || EXIT[this.lib.accessories[id].enter === 'fade' ? 'fade' : 'pop']
    item.g.style.transformBox = 'fill-box'
    item.g.style.transformOrigin = '50% 50%'
    item.g.animate(frames, { duration: ms, easing: 'ease-in', fill: 'forwards' }).onfinish = () => item.g.remove()
  }

  startLoops(id) {
    const item = this.shown.get(id)
    if (!item || item.running.length || this.reduced) return
    item.running = item.loops.map(({ el, anim }) => {
      if (anim.origin) { el.style.transformBox = 'fill-box'; el.style.transformOrigin = anim.origin }
      const curve = CURVE[anim.ease || 'inOut']
      const frames = anim.frames.map((f) => ({ ...(typeof f === 'string' ? { transform: f } : f), easing: curve }))
      return el.animate(frames, { duration: anim.ms, delay: anim.delay || 0, iterations: anim.once ? 1 : Infinity, fill: anim.once ? 'both' : 'none' })
    })
  }

  stopLoops(item) {
    for (const a of item?.running || []) a.cancel()
    if (item) item.running = []
  }

  // The worn accessory stays on unless the playing moment needs its slot or already wears two.
  syncWorn(enter = true) {
    const worn = this.look.worn
    const mine = this.current?.mine || []
    for (const id of [...this.shown.keys()]) if (id !== worn && !mine.includes(id)) this.hide(id, !enter)
    if (!worn) return
    const slot = this.lib.accessories[worn].slot
    const fits = mine.includes(worn) || (mine.length < 2 && !mine.some((a) => this.lib.accessories[a].slot === slot))
    if (fits) this.show(worn, enter)
    else this.hide(worn)
  }

  // ---------- Moments ----------

  // Resolves true when the moment ran to its end, false when something replaced or stopped it.
  async play(id, { loop = false, hold = false } = {}) {
    const moment = this.lib.moments[id]
    const a = this.avatar
    this.stop(true)
    const token = ++this.token
    this.internal = true
    try { a.play('idle') } finally { this.internal = false }
    a.noteActivity?.(false)
    this.current = { id, loop, mine: accessoriesOf(moment) }
    this.syncWorn()
    const reduced = this.reduced
    const steps = reduced ? moment.reduced : moment.steps
    for (let i = 0; token === this.token; ) {
      if (i >= steps.length) {
        if (!this.current.loop) break
        i = reduced ? 0 : moment.loopFrom || 0
        a.noteActivity?.(false)
      }
      const step = steps[i++]
      if (step.wait) await this.wait(step.wait / this.time.speed)
      else this.step(step, reduced)
    }
    if (token !== this.token) return false
    this.settle(false, hold)
    return true
  }

  // Lets a looping moment finish its current pass instead of cutting it.
  setLoop(on) {
    if (this.current) this.current.loop = on
  }

  stop(instant = false) {
    ++this.token
    for (const [timer, resolve] of this.waits) { clearTimeout(timer); resolve() }
    this.waits.clear()
    if (this.current) this.settle(instant)
  }

  wait(ms) {
    return new Promise((resolve) => {
      const timer = setTimeout(() => { this.waits.delete(timer); resolve() }, ms)
      this.waits.set(timer, resolve)
    })
  }

  step(s, reduced) {
    const a = this.avatar
    const speed = this.time.speed
    if (s.lock) { a._boredRoutine = null; a._expressionLock = true; a._wanderTarget.x = a._wanderTarget.y = 0 }
    if (s.unlock) a._releaseExpressionLock()
    if (s.pose) {
      a.setState(s.pose, { duration: (s.ms ?? 320) / speed, ease: EASE[s.ease || 'out'], keepGazeLock: true, notify: false })
      if (s.set) Object.assign(a._toPose, s.set)
    }
    if (s.gaze) {
      a._expressionLock = false
      const lookSpeed = s.speed ?? 0.3
      a._boredRoutine = { index: 0, nextAt: performance.now(), steps: s.gaze.map(([x, y, hold]) => ({ x, y, hold: hold / speed, lookSpeed })) }
    }
    if (s.head && !reduced) {
      const el = a._headMotion
      const curve = CURVE[s.ease || 'inOut']
      el.style.transformBox = 'view-box'
      el.style.transformOrigin = s.origin || '120px 120px'
      this.anims.push(el.animate(s.head.map((transform) => ({ transform, easing: curve })), { duration: s.ms / speed, iterations: s.times || 1, fill: 'forwards' }))
    }
    if (s.fx && !reduced) this.fx(s, speed)
    if (s.on) { this.show(s.on, !s.instant); if (!reduced) this.startLoops(s.on) }
    if (s.off) {
      if (s.off === this.look.worn) this.stopLoops(this.shown.get(s.off))
      else this.hide(s.off, false, s.exit)
    }
    a._resumeFrames?.()
  }

  fx(s, speed) {
    const a = this.avatar
    const start = performance.now()
    const ms = (s.ms || 0) / speed
    if (s.fx === 'nod') a._eyeNod = { start, duration: 760 }
    if (s.fx === 'bob') a._eyeBob = { start, duration: ms || 620, amp: s.amp || 7 }
    if (s.fx === 'shake') a._surpriseShake = { start, duration: 420 / speed }
    if (s.fx === 'blink') a._blinkAnim = { start, duration: 170 }
    if (s.fx === 'wink') this.wink = { start, ms: ms || 420 }
  }

  settle(instant, keepPose = false) {
    const a = this.avatar
    const el = a._headMotion
    const held = instant || this.reduced ? 'none' : getComputedStyle(el).transform
    for (const anim of this.anims) anim.cancel()
    this.anims = []
    el.style.transform = ''
    if (held && held !== 'none') {
      const back = el.animate([{ transform: held }, { transform: 'none' }], { duration: 320, easing: CURVE.out })
      this.anims.push(back)
      back.onfinish = () => { if (this.anims.at(-1) === back) el.style.transformOrigin = '' }
    } else el.style.transformOrigin = ''
    a._boredRoutine = null
    a._wanderTarget.x = a._wanderTarget.y = 0
    a._nextWanderAt = performance.now() + 700
    a._eyeBob = a._eyeNod = a._surpriseShake = a._angryEyeDrop = null
    this.wink = null
    const mine = this.current.mine
    this.current = null
    if (!instant && !keepPose) a.setState('idle', { duration: 360, notify: false })
    for (const id of mine) if (id === this.look.worn) this.stopLoops(this.shown.get(id))
    this.syncWorn(!instant)
  }

  // ---------- Draw hook: time-of-day lids and blink rate, and the wink ----------

  draw(now) {
    const a = this.avatar
    if (this.rimPending) this.applyRim()
    const time = this.time
    if (time.lid && a._state !== 'input' && a._state !== 'sleep') {
      for (const lid of [a._leftTop, a._rightTop]) lid.setAttribute('y', (Number(lid.getAttribute('y')) + time.lid).toFixed(2))
    }
    if (time.blink !== 1 && a._nextBlinkAt !== this.blinkSeen) {
      a._nextBlinkAt = now + (a._nextBlinkAt - now) / time.blink
      this.blinkSeen = a._nextBlinkAt
    }
    if (this.wink) {
      const t = (now - this.wink.start) / this.wink.ms
      if (t >= 1) this.wink = null
      else a._rightEye.setAttribute('transform', `${a._rightEye.getAttribute('transform')} scale(1 ${(1 - 0.92 * Math.sin(Math.PI * t)).toFixed(3)})`)
    }
  }
}
