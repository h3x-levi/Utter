const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const { pathToFileURL } = require('node:url')

const table = require('./companion-routes.test.json')
const libraryFile = path.join(__dirname, 'companion-moments.json')
const playerUrl = pathToFileURL(path.join(__dirname, 'companion-player.js')).href
const siteRobot = path.join(__dirname, '..', '..', 'website', 'public', 'robot')
const fragmentFile = process.env.FRAGMENT && path.resolve(process.env.FRAGMENT)

const BASE = {
  moments: ['lean-in', 'tap-along', 'jot', 'tie-string', 'listen-hard', 'done', 'oops', 'milestone', 'take-notes', 'meeting-done', 'stretch',
    'sip', 'focus-on', 'break-yawn', 'goal-dance', 'hello', 'bye', 'late-yawn', 'doze', 'dizzy', 'curious', 'bob-music'],
  accessories: ['headphones', 'notepad', 'bow', 'glass', 'party-hat', 'nightcap', 'bell', 'timer', 'notes', 'zz', 'sparkles', 'stars'],
  palette: ['red', 'gold', 'navy', 'line', 'paper', 'blue', 'water', 'white'],
  finishes: ['ink', 'navy', 'tape-red', 'gold', 'porcelain', 'chrome', 'mixtape'],
  wear: ['headphones', 'bow', 'party-hat', 'nightcap'],
}
const PACKETS = {
  C1: { prefix: 'w-', groups: ['dictation', 'meetings'], moments: 26, accessories: 4,
    signals: ['listening', 'talking', 'quiet', 'thinking', 'done', 'error', 'notice', 'island', 'meeting'],
    owns: ['lean-in', 'tap-along', 'listen-hard', 'jot', 'done', 'oops', 'milestone', 'tie-string', 'take-notes', 'meeting-done'] },
  C2: { prefix: 'c-', groups: ['care'], moments: 11, accessories: 4, signals: ['reminder', 'goal'], owns: ['stretch', 'sip', 'focus-on', 'break-yawn', 'goal-dance'] },
  C3: { prefix: 't-', groups: ['mood'], moments: 24, accessories: 4, signals: ['shown', 'hiding', 'ambient'], owns: ['hello', 'bye', 'late-yawn', 'doze'] },
  C4: { prefix: 'p-', groups: ['play'], moments: 20, accessories: 2, signals: ['poke', 'near', 'fling'], owns: ['dizzy', 'curious'] },
  C5: { prefix: 's-', groups: ['seasons'], moments: 18, accessories: 10, wear: 8, finishes: 3, signals: ['ambient'], owns: [] },
}
const KNOWN = 'Known base item, fixed at MERGE (plan §2.9 Merge)'

const TURN = { words: 'number', total: 'number', destination: ['app', 'note', 'memory'], remembered: [true, false], timed: [true, false], goal: ['dictation'] }
const DETAIL = {
  listening: { mode: ['recording', 'handsFree'], destination: ['app', 'note', 'memory'] },
  talking: {}, quiet: {}, thinking: {}, done: TURN, error: TURN, notice: TURN, island: TURN,
  meeting: { state: ['recording', 'saved'], minutes: 'number' },
  reminder: { kind: ['stretch', 'water', 'pomodoro'], focus: [true, false] },
  goal: { kind: ['hydration', 'stretch', 'focus'] },
  shown: {}, hiding: {}, fling: { speed: 'number' }, near: {}, poke: { count: 'number' }, ambient: {}, music: {},
}
const RETIRED = ['idle', 'dozing', 'delivered', 'remembered']
const HOLD = ['listening', 'talking', 'quiet']
const DATE_KEYS = ['month', 'day', 'weekday']

const POSES = ['idle', 'happy', 'sad', 'angry', 'sleepy', 'input', 'sleep', 'surprise']
const EASES = ['out', 'inOut', 'linear']
const SET_KEYS = ['w', 'h', 'topY', 'bottomY', 'topAL', 'topAR']
const STEP = { lock: [], unlock: [], pose: ['ms', 'ease', 'set'], gaze: ['speed'], head: ['ms', 'times', 'ease', 'origin'], fx: ['ms', 'amp'], on: ['instant'], off: ['exit'], wait: [] }
const REDUCED = ['pose', 'set', 'on', 'instant', 'off', 'exit', 'wait', 'lock', 'unlock']
const SHAPE_KEYS = ['el', 'kids', 'anim', 'd', 'x', 'y', 'width', 'height', 'rx', 'ry', 'cx', 'cy', 'r', 'fill', 'fill-opacity', 'stroke', 'stroke-width',
  'stroke-linecap', 'stroke-linejoin', 'opacity', 'transform', 'pathLength', 'stroke-dasharray']
const NUMERIC = ['x', 'y', 'width', 'height', 'rx', 'ry', 'cx', 'cy', 'r', 'fill-opacity', 'stroke-width', 'opacity', 'pathLength']
const NEEDS = { g: [], path: ['d'], rect: ['width', 'height'], circle: ['r'], ellipse: ['rx', 'ry'] }
const NUM = String.raw`-?(?:\d+\.?\d*|\.\d+)`
const HEX = /^#[0-9A-Fa-f]{6}$/

const isNum = (v) => typeof v === 'number' && Number.isFinite(v)
const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v)
const has = Object.hasOwn
const waits = (seq) => seq.reduce((n, s) => n + (isNum(s?.wait) ? s.wait : 0), 0)
const ons = (seq) => [...new Set(seq.filter((s) => s?.on).map((s) => s.on))]
const poses = (seq) => seq.filter((s) => s?.pose).map((s) => s.pose)
const targets = (r) => (Array.isArray(r.moments) ? r.moments : [r.moment])
const canon = (v) => (Array.isArray(v) ? v.map(canon) : isObj(v) ? Object.fromEntries(Object.keys(v).sort().map((k) => [k, canon(v[k])])) : v)
const range = (from, to) => Array.from({ length: to - from + 1 }, (_, i) => from + i)

function cssTransform(text, fns) {
  const units = { translateX: ['px'], translateY: ['px'], translate: ['px', 'px'], rotate: ['deg'], scale: ['', ''] }
  const re = /\s*([A-Za-z]+)\(([^()]*)\)\s*/y
  const list = []
  for (let pos = 0; pos < text.length; pos = re.lastIndex) {
    re.lastIndex = pos
    const m = re.exec(text)
    if (!m || !fns.includes(m[1])) return null
    const args = m[2].split(',').map((a) => a.trim())
    if (args.length > units[m[1]].length) return null
    const nums = []
    for (const [i, a] of args.entries()) {
      const n = new RegExp(`^(${NUM})(px|deg)?$`).exec(a)
      if (!n || (n[2] ?? '') !== units[m[1]][i]) return null
      nums.push(Number(n[1]))
    }
    list.push({ fn: m[1], nums })
  }
  return list.length ? list : null
}

function svgTransform(text) {
  const arity = { translate: [1, 2], rotate: [1, 3], scale: [1, 2] }
  const re = /\s*([A-Za-z]+)\(([^()]*)\)\s*/y
  let count = 0
  for (let pos = 0; pos < text.length; pos = re.lastIndex) {
    re.lastIndex = pos
    const m = re.exec(text)
    if (!m || !arity[m[1]]) return false
    const args = m[2].trim().split(/[\s,]+/)
    if (!arity[m[1]].includes(args.length) || !args.every((a) => new RegExp(`^${NUM}$`).test(a))) return false
    count++
  }
  return count > 0
}

function pathOk(d) {
  const arity = { M: 2, L: 2, H: 1, V: 1, C: 6, Q: 4, Z: 0 }
  const token = new RegExp(String.raw`[A-Za-z]|${NUM}(?:e-?\d+)?`, 'g')
  if (d.replace(token, '').replace(/[\s,]/g, '')) return false
  const tokens = d.match(token) || []
  if (tokens[0] !== 'M') return false
  for (let i = 0; i < tokens.length; ) {
    const cmd = tokens[i++]
    if (!has(arity, cmd)) return false
    let n = 0
    while (i < tokens.length && !/^[A-Za-z]$/.test(tokens[i])) { n++; i++ }
    if (arity[cmd] === 0 ? n !== 0 : n === 0 || n % arity[cmd] !== 0) return false
  }
  return true
}

function checker(lib) {
  const problems = []
  const bad = (at, msg, code = 'rule') => problems.push({ code, at, msg })
  const colourOk = (v) => v === 'none' || v === 'body' || v === 'eyes' || has(lib.palette, v)
  const registry = (signal) => ({ time: Object.keys(lib.times), hour: range(0, 23), weekday: range(0, 6), month: range(1, 12), day: range(1, 31), ...DETAIL[signal] })
  const inDomain = (domain, v) => (domain === 'number' ? isNum(v) && v >= 0 : domain.includes(v))

  function shape(s, at) {
    if (!isObj(s) || !has(NEEDS, s.el)) return bad(at, `el must be g, path, rect, circle or ellipse (got ${JSON.stringify(s?.el)})`)
    for (const k of Object.keys(s)) if (!SHAPE_KEYS.includes(k)) bad(at, `unknown shape attribute "${k}"`)
    for (const k of NEEDS[s.el]) if (!has(s, k)) bad(at, `${s.el} needs ${k}`)
    for (const k of NUMERIC) if (has(s, k) && !isNum(s[k])) bad(at, `${k} must be a number`)
    for (const k of ['opacity', 'fill-opacity']) if (isNum(s[k]) && (s[k] < 0 || s[k] > 1)) bad(at, `${k} must be within 0 and 1`)
    if (s.el === 'path' && !(typeof s.d === 'string' && pathOk(s.d))) bad(at, 'd uses absolute M L H V C Q Z only and starts with M')
    for (const k of ['fill', 'stroke']) if (has(s, k) && !colourOk(s[k])) bad(at, `${k} ${JSON.stringify(s[k])} must be a palette token, body, eyes or none`)
    if (s.el !== 'g' && !has(s, 'fill')) bad(at, 'leaf shapes declare fill')
    if (has(s, 'stroke-linecap') && !['butt', 'round', 'square'].includes(s['stroke-linecap'])) bad(at, 'stroke-linecap is butt, round or square')
    if (has(s, 'stroke-linejoin') && !['miter', 'round', 'bevel'].includes(s['stroke-linejoin'])) bad(at, 'stroke-linejoin is miter, round or bevel')
    if (has(s, 'transform') && !(typeof s.transform === 'string' && svgTransform(s.transform))) bad(at, 'transform uses translate, rotate and scale only')
    if (has(s, 'stroke-dasharray') || has(s, 'pathLength')) {
      const dash = typeof s['stroke-dasharray'] === 'string' ? s['stroke-dasharray'].trim().split(/[\s,]+/).map(Number) : []
      if (!(s.pathLength > 0) || dash.length !== 2 || !dash.every((n) => n >= 0) || dash[0] + dash[1] < s.pathLength) {
        bad(at, 'pathLength and stroke-dasharray come together: one dash and one gap with dash + gap >= pathLength')
      }
    }
    if (s.el === 'g') {
      if (!Array.isArray(s.kids) || !s.kids.length) bad(at, 'g needs kids')
      else s.kids.forEach((kid, i) => shape(kid, `${at}.kids[${i}]`))
    } else if (has(s, 'kids')) bad(at, 'only g has kids')
    if (has(s, 'anim')) anim(s, `${at}.anim`)
  }

  function anim(s, at) {
    const a = s.anim
    if (!isObj(a)) return bad(at, 'anim is an object')
    for (const k of Object.keys(a)) if (!['frames', 'ms', 'delay', 'once', 'ease', 'origin'].includes(k)) bad(at, `unknown anim key "${k}"`)
    if (!Array.isArray(a.frames) || a.frames.length < 2) bad(at, 'frames needs at least two keyframes')
    for (const [i, f] of (Array.isArray(a.frames) ? a.frames : []).entries()) {
      const frame = typeof f === 'string' ? { transform: f } : f
      const where = `${at}.frames[${i}]`
      if (!isObj(frame)) { bad(where, 'a frame is a transform string or an object'); continue }
      for (const k of Object.keys(frame)) if (!['transform', 'opacity', 'offset', 'strokeDashoffset'].includes(k)) bad(where, `unknown frame key "${k}"`)
      if (has(frame, 'transform') && !(typeof frame.transform === 'string' && cssTransform(frame.transform, ['translate', 'translateX', 'translateY', 'rotate', 'scale']))) {
        bad(where, `transform ${JSON.stringify(frame.transform)} uses translate(px), rotate(deg) and scale only`)
      }
      for (const k of ['opacity', 'offset']) if (has(frame, k) && !(isNum(frame[k]) && frame[k] >= 0 && frame[k] <= 1)) bad(where, `${k} must be within 0 and 1`)
      if (has(frame, 'strokeDashoffset') && !(isNum(frame.strokeDashoffset) && has(s, 'stroke-dasharray'))) bad(where, 'strokeDashoffset needs a number and a stroke-dasharray')
    }
    if (!(isNum(a.ms) && a.ms > 0)) bad(at, 'ms must be a positive number')
    if (has(a, 'delay') && !isNum(a.delay)) bad(at, 'delay must be a number')
    if (has(a, 'once') && typeof a.once !== 'boolean') bad(at, 'once must be true or false')
    if (has(a, 'ease') && ![...EASES, 'back'].includes(a.ease)) bad(at, 'ease is out, inOut, linear or back')
    if (has(a, 'origin') && !/^-?\d+(\.\d+)?% -?\d+(\.\d+)?%$/.test(a.origin)) bad(at, 'origin is "X% Y%"')
    if (has(a, 'origin') && has(s, 'transform')) bad(at, 'an element with anim.origin has no static transform')
  }

  function step(s, at, id, reduced) {
    if (!isObj(s)) return bad(at, 'a step is an object')
    const keys = Object.keys(s)
    const actions = keys.filter((k) => has(STEP, k))
    if (actions.length !== 1) return bad(at, `a step has exactly one action key (has ${actions.join(', ') || 'none'})`)
    const [act] = actions
    for (const k of keys) if (k !== act && !STEP[act].includes(k)) bad(at, `"${k}" does not go with ${act}`)
    if (reduced) for (const k of keys) if (!REDUCED.includes(k)) bad(at, `reduced steps use only pose, set, on, off, wait, lock and unlock (has ${k})`)
    if ((act === 'lock' || act === 'unlock') && s[act] !== true) bad(at, `${act} must be true`)
    if (has(s, 'ms') && !(isNum(s.ms) && s.ms >= 0)) bad(at, 'ms must be a number >= 0')
    if (has(s, 'ease') && !EASES.includes(s.ease)) bad(at, 'ease is out, inOut or linear')
    if (act === 'pose') {
      if (!POSES.includes(s.pose)) bad(at, `unknown pose ${JSON.stringify(s.pose)}`)
      if (has(s, 'set') && !isObj(s.set)) bad(at, 'set is an object')
      for (const [k, v] of Object.entries(isObj(s.set) ? s.set : {})) {
        if (k === 'rx' && BASE.moments.includes(id)) bad(at, 'set.rx is dead data (upstream draws rx = w/2)', 'set.rx')
        else if (!SET_KEYS.includes(k)) bad(at, `set.${k} is not one of ${SET_KEYS.join(', ')}`)
        if (!isNum(v)) bad(at, `set.${k} must be a number`)
      }
    }
    if (act === 'gaze') {
      if (!Array.isArray(s.gaze) || !s.gaze.length || !s.gaze.every((g) => Array.isArray(g) && g.length === 3 && g.every(isNum) && g[2] >= 0)) {
        bad(at, 'gaze is a list of [x, y, holdMs]')
      }
      if (has(s, 'speed') && !(isNum(s.speed) && s.speed > 0)) bad(at, 'speed must be a positive number')
    }
    if (act === 'head') {
      const frames = Array.isArray(s.head) ? s.head.map((f) => (typeof f === 'string' ? cssTransform(f, ['translateX', 'translateY', 'rotate', 'scale']) : null)) : []
      if (frames.length < 2) bad(at, 'head needs at least two keyframes')
      frames.forEach((f, i) => { if (!f) bad(at, `head[${i}] ${JSON.stringify(s.head[i])} uses translateX(px), translateY(px), rotate(deg) and scale(a[, b]) only`) })
      if (frames.length >= 2 && frames.every(Boolean)) {
        const names = frames.map((f) => f.map((x) => x.fn).join(' '))
        if (new Set(names).size > 1) bad(at, `every head keyframe has the same function list (has ${[...new Set(names)].map((n) => `"${n}"`).join(' and ')})`)
        else {
          const fns = frames[0].map((x) => x.fn)
          const skew = fns.some((fn, j) => fn === 'scale' && fns.indexOf('rotate', j) > j && frames.some((f) => f[j].nums.length === 2 && f[j].nums[0] !== f[j].nums[1]))
          if (skew) bad(at, 'non-uniform scale is never left of a rotate', id === 'stretch' ? 'stretch-order' : 'rule')
        }
      }
      if (!(isNum(s.ms) && s.ms > 0)) bad(at, 'head needs ms > 0')
      if (has(s, 'times') && !(Number.isInteger(s.times) && s.times >= 1)) bad(at, 'times must be a whole number >= 1')
      if (has(s, 'origin') && !/^-?\d+(\.\d+)?px -?\d+(\.\d+)?px$/.test(s.origin)) bad(at, 'origin is "Npx Npx"')
    }
    if (act === 'fx') {
      if (!['nod', 'bob', 'shake', 'blink', 'wink'].includes(s.fx)) bad(at, `unknown fx ${JSON.stringify(s.fx)}`)
      if (has(s, 'amp') && !isNum(s.amp)) bad(at, 'amp must be a number')
    }
    if (act === 'on' || act === 'off') if (!has(lib.accessories, s[act])) bad(at, `${act} names unknown accessory ${JSON.stringify(s[act])}`)
    if (has(s, 'instant') && typeof s.instant !== 'boolean') bad(at, 'instant must be true or false')
    if (has(s, 'exit') && !['lift', 'pop', 'fade'].includes(s.exit)) bad(at, 'exit is lift, pop or fade')
    if (act === 'wait' && !(isNum(s.wait) && s.wait > 0)) bad(at, 'wait must be a positive number of ms')
  }

  function moment(id, m) {
    const at = `moments.${id}`
    if (!isObj(m)) return bad(at, 'a moment is an object')
    for (const k of Object.keys(m)) if (!['group', 'name', 'trigger', 'steps', 'reduced', 'loopFrom', 'unwired'].includes(k)) bad(at, `unknown moment key "${k}"`)
    if (!has(lib.groups, m.group)) bad(at, `group ${JSON.stringify(m.group)} is not in groups`)
    for (const k of ['name', 'trigger']) if (!(typeof m[k] === 'string' && m[k].trim())) bad(at, `${k} must be a non-empty string`)
    if (has(m, 'unwired') && !(typeof m.unwired === 'string' && m.unwired.trim())) bad(at, 'unwired says why, as a string')
    if (!Array.isArray(m.steps) || !m.steps.length || !Array.isArray(m.reduced) || !m.reduced.length) return bad(at, 'steps and reduced are non-empty lists')
    m.steps.forEach((s, i) => step(s, `${at}.steps[${i}]`, id, false))
    m.reduced.forEach((s, i) => step(s, `${at}.reduced[${i}]`, id, true))
    const mine = ons(m.steps)
    if (new Set([...mine, ...ons(m.reduced)]).size > 2) bad(at, 'at most 2 accessories per moment')
    for (const a of ons(m.reduced)) if (!mine.includes(a)) bad(at, `reduced puts on ${a}, which steps never do`)
    for (const [name, seq] of [['steps', m.steps], ['reduced', m.reduced]]) {
      const worn = new Set()
      seq.forEach((s, i) => {
        if (s?.on) worn.add(s.on)
        if (s?.off && !worn.has(s.off)) bad(`${at}.${name}[${i}]`, `off ${JSON.stringify(s.off)} is not an accessory this moment put on`)
      })
    }
    if (has(m, 'loopFrom')) {
      if (!(Number.isInteger(m.loopFrom) && m.loopFrom >= 0 && m.loopFrom < m.steps.length)) return bad(at, 'loopFrom must index a step')
      m.steps.slice(m.loopFrom).forEach((s, j) => {
        for (const k of ['on', 'off', 'lock', 'unlock']) if (isObj(s) && has(s, k)) bad(`${at}.steps[${m.loopFrom + j}]`, `the loop section has no ${k}`)
      })
      const pass = waits(m.steps.slice(m.loopFrom))
      const again = waits(m.reduced)
      if (!(pass > 0 && pass <= 8000)) bad(at, `a loop pass waits more than 0 and at most 8 s (steps from loopFrom wait ${pass} ms)`)
      if (!(again > 0 && again <= 8000)) bad(at, `reduced loops too, so it waits more than 0 and at most 8 s (waits ${again} ms)`)
    } else {
      const total = waits(m.steps)
      if (total < 1500 || total > 12000) bad(at, `a moment waits 1.5 to 12 s in total (waits ${total} ms)`)
    }
  }

  function accessory(id, a) {
    const at = `accessories.${id}`
    if (!isObj(a)) return bad(at, 'an accessory is an object')
    for (const k of Object.keys(a)) if (!['name', 'slot', 'layer', 'enter', 'shapes', 'wear'].includes(k)) bad(at, `unknown accessory key "${k}"`)
    if (!(typeof a.name === 'string' && a.name.trim())) bad(at, 'name must be a non-empty string')
    if (!['ears', 'hands', 'top', 'air', 'ring'].includes(a.slot)) bad(at, 'slot is ears, hands, top, air or ring')
    if (!['behind', 'head', 'front'].includes(a.layer)) bad(at, 'layer is behind, head or front')
    if (!['drop', 'pop', 'rise', 'fade'].includes(a.enter)) bad(at, 'enter is drop, pop, rise or fade')
    if (has(a, 'wear') && typeof a.wear !== 'boolean') bad(at, 'wear must be true or false')
    if (!Array.isArray(a.shapes) || !a.shapes.length) bad(at, 'shapes is a non-empty list')
    else a.shapes.forEach((s, i) => shape(s, `${at}.shapes[${i}]`))
  }

  function finish(id, f) {
    const at = `finishes.${id}`
    if (!isObj(f)) return bad(at, 'a finish is an object')
    for (const k of Object.keys(f)) {
      if (k === 'askFirst' && BASE.finishes.includes(id)) bad(at, 'askFirst gate is dropped (owner approved every finish)', 'askFirst')
      else if (!['name', 'body', 'eyes', 'outline', 'swap', 'shapes'].includes(k)) bad(at, `unknown finish key "${k}"`)
    }
    if (!(typeof f.name === 'string' && f.name.trim())) bad(at, 'name must be a non-empty string')
    for (const k of ['body', 'eyes']) if (!HEX.test(f[k])) bad(at, `${k} must be a #RRGGBB colour`)
    if (has(f, 'outline') && !['dark', 'light'].includes(f.outline)) bad(at, 'outline is dark or light')
    if (has(f, 'swap')) {
      if (!isObj(f.swap)) bad(at, 'swap maps palette token to palette token')
      else for (const [k, v] of Object.entries(f.swap)) if (!has(lib.palette, k) || !has(lib.palette, v)) bad(at, `swap ${k} -> ${v} must map palette tokens`)
    }
    if (has(f, 'shapes')) {
      if (!Array.isArray(f.shapes) || !f.shapes.length) bad(at, 'shapes is a non-empty list')
      else f.shapes.forEach((s, i) => shape(s, `${at}.shapes[${i}]`))
    }
  }

  function route(r, at) {
    if (!isObj(r)) return bad(at, 'a route is an object')
    for (const k of Object.keys(r)) if (!['signal', 'moment', 'moments', 'is', 'atLeast', 'every', 'cooldown'].includes(k)) bad(at, `unknown route key "${k}"`)
    if (RETIRED.includes(r.signal)) return bad(at, `"${r.signal}" is a retired signal (plan §2.1)`, 'retired-signal')
    if (!has(DETAIL, r.signal)) return bad(at, `unknown signal ${JSON.stringify(r.signal)}`)
    if (has(r, 'moment') === has(r, 'moments')) bad(at, 'a route has exactly one of moment or moments')
    if (has(r, 'moments') && !(Array.isArray(r.moments) && r.moments.length && new Set(r.moments).size === r.moments.length)) bad(at, 'moments is a non-empty list without repeats')
    for (const id of targets(r)) if (!has(lib.moments, id)) bad(at, `routes to unknown moment ${JSON.stringify(id)}`)
    const known = registry(r.signal)
    if (has(r, 'is')) {
      if (!isObj(r.is) || !Object.keys(r.is).length) bad(at, 'is is a non-empty object')
      else for (const [k, v] of Object.entries(r.is)) {
        if (!has(known, k)) { bad(at, `is.${k} is not in the ${r.signal} detail (plan §2.1-2.2)`); continue }
        const values = Array.isArray(v) ? v : [v]
        if (!values.length) bad(at, `is.${k} lists no values`)
        for (const value of values) if (!inDomain(known[k], value)) bad(at, `is.${k} ${JSON.stringify(value)} never occurs in the ${r.signal} detail`)
      }
    }
    if (has(r, 'atLeast')) {
      if (!isObj(r.atLeast) || !Object.keys(r.atLeast).length) bad(at, 'atLeast is a non-empty object')
      else for (const [k, v] of Object.entries(r.atLeast)) {
        if (!has(known, k) || !(known[k] === 'number' || known[k].every(isNum))) bad(at, `atLeast.${k} is not a number in the ${r.signal} detail (plan §2.1-2.2)`)
        if (!isNum(v)) bad(at, `atLeast.${k} must be a number`)
      }
    }
    if (has(r, 'every') && !(isNum(r.every) && r.every > 0 && has(known, 'words') && has(known, 'total'))) bad(at, 'every needs a positive number and a turn-end signal with words and total')
    if (has(r, 'cooldown') && !(isNum(r.cooldown) && r.cooldown > 0)) bad(at, 'cooldown must be a positive number of ms')
    if (r.signal === 'ambient') {
      const dated = isObj(r.is) && DATE_KEYS.some((k) => has(r.is, k))
      const floor = dated ? 10800000 : 600000
      if (!(r.cooldown >= floor)) bad(at, `ambient routes${dated ? ' on a date' : ''} cool down for at least ${floor} ms`)
    }
  }

  function routes(list, offset = 0) {
    const open = new Map()
    list.forEach((r, i) => {
      const at = `routes[${offset + i}]`
      route(r, at)
      if (!isObj(r)) return
      if (open.has(r.signal)) bad(at, `never reached: ${open.get(r.signal)} routes every ${r.signal} first`)
      else if (!['is', 'atLeast', 'every', 'cooldown'].some((k) => has(r, k))) open.set(r.signal, at)
      for (const id of targets(r)) {
        const m = lib.moments[id]
        if (!isObj(m) || !Array.isArray(m.steps) || !Array.isArray(m.reduced)) continue
        if (HOLD.includes(r.signal) && (poses(m.steps).at(-1) !== 'input' || poses(m.reduced).at(-1) !== 'input')) bad(at, `${r.signal} holds its pose, so ${id} ends on pose input (steps and reduced)`)
        const recording = r.signal === 'meeting' && [r.is?.state].flat().includes('recording')
        if ((r.signal === 'thinking' || recording) && !has(m, 'loopFrom')) bad(at, `${id} loops (loopFrom), since ${r.signal}${recording ? ' recording' : ''} lasts until replaced`)
      }
    })
  }

  function strings(v, at) {
    if (typeof v === 'string' && v.includes('—')) bad(at, 'no em dash in library strings')
    else if (Array.isArray(v)) v.forEach((x, i) => strings(x, `${at}[${i}]`))
    else if (isObj(v)) for (const [k, x] of Object.entries(v)) strings(x, `${at}.${k}`)
  }

  function shared(own) {
    const routed = new Set((own.routes || []).filter(isObj).flatMap(targets))
    const blank = (id) => JSON.stringify(canon(lib.moments[id].steps.map((s) => (isObj(s) && has(s, 'wait') ? { ...s, wait: 0 } : s))))
    const steps = new Map()
    for (const id of Object.keys(lib.moments)) if (Array.isArray(lib.moments[id]?.steps)) steps.set(id, blank(id))
    for (const id of own.moments) {
      const m = lib.moments[id]
      if (!isObj(m)) continue
      if (!m.unwired && !routed.has(id)) bad(`moments.${id}`, 'no route reaches this moment')
      const twin = [...steps].find(([other, s]) => other !== id && s === steps.get(id))
      if (twin) bad(`moments.${id}`, `same steps as ${twin[0]} once waits are blanked`)
      const sameName = Object.keys(lib.moments).find((other) => other !== id && lib.moments[other]?.name === m.name)
      if (sameName) bad(`moments.${id}`, `same name as ${sameName}`)
    }
    const used = new Set(Object.values(lib.moments).flatMap((m) => (Array.isArray(m?.steps) ? ons(m.steps) : [])))
    for (const id of own.accessories) {
      if (!used.has(id) && lib.accessories[id]?.wear !== true) bad(`accessories.${id}`, 'no moment puts this on and it is not wearable')
      const sameName = Object.keys(lib.accessories).find((other) => other !== id && lib.accessories[other]?.name === lib.accessories[id]?.name)
      if (sameName) bad(`accessories.${id}`, `same name as ${sameName}`)
    }
    for (const id of own.finishes) {
      const sameName = Object.keys(lib.finishes).find((other) => other !== id && lib.finishes[other]?.name === lib.finishes[id]?.name)
      if (sameName) bad(`finishes.${id}`, `same name as ${sameName}`)
    }
  }

  return {
    problems,
    bad,
    library(raw) {
      if (lib.version !== 1) bad('version', 'version is 1')
      if (lib.credit !== 'Robot by CX ArtLab') bad('credit', 'credit stays "Robot by CX ArtLab"')
      if (lib.box !== 240) bad('box', 'box is 240')
      if (!has(lib.finishes, lib.defaults?.finish) || !has(lib.times, lib.defaults?.time)) bad('defaults', 'defaults name a finish and a time')
      for (const [id, label] of Object.entries(lib.groups)) if (!(typeof label === 'string' && label.trim())) bad(`groups.${id}`, 'a group label is a non-empty string')
      for (const h of range(0, 23)) {
        const hits = Object.values(lib.times).filter(({ from, to }) => (from < to ? h >= from && h < to : h >= from || h < to))
        if (hits.length !== 1) bad('times', `hour ${h} falls in ${hits.length} times of day`)
      }
      for (const [id, swatch] of Object.entries(lib.palette)) if (!(Array.isArray(swatch) && swatch.length === 2 && swatch.every((c) => HEX.test(c)))) bad(`palette.${id}`, 'a palette token is [light, dark] #RRGGBB')
      for (const [id, f] of Object.entries(lib.finishes)) finish(id, f)
      for (const [id, a] of Object.entries(lib.accessories)) accessory(id, a)
      for (const [id, m] of Object.entries(lib.moments)) moment(id, m)
      routes(lib.routes)
      strings(raw, 'library')
      const prefixes = Object.values(PACKETS).map((p) => p.prefix)
      for (const [kind, ids] of [['moments', Object.keys(lib.moments)], ['accessories', Object.keys(lib.accessories)], ['palette', Object.keys(lib.palette)]]) {
        for (const id of ids) if (!BASE[kind].includes(id) && !prefixes.some((p) => id.startsWith(p))) bad(`${kind}.${id}`, `new ids start with a packet prefix (${prefixes.join(' ')})`)
      }
      for (const [id, m] of Object.entries(lib.moments)) {
        const row = Object.values(PACKETS).find((p) => id.startsWith(p.prefix))
        if (row && !row.groups.includes(m?.group)) bad(`moments.${id}`, `${row.prefix} moments belong to ${row.groups.join(' or ')}`)
      }
      shared({ moments: Object.keys(lib.moments), accessories: Object.keys(lib.accessories), finishes: Object.keys(lib.finishes), routes: lib.routes })
    },
    fragment(frag, row) {
      for (const [id, swatch] of Object.entries(frag.palette || {})) if (!(Array.isArray(swatch) && swatch.length === 2 && swatch.every((c) => HEX.test(c)))) bad(`palette.${id}`, 'a palette token is [light, dark] #RRGGBB')
      for (const [id, label] of Object.entries(frag.groups || {})) if (!(typeof label === 'string' && label.trim())) bad(`groups.${id}`, 'a group label is a non-empty string')
      for (const id of Object.keys(frag.finishes || {})) finish(id, lib.finishes[id])
      for (const id of Object.keys(frag.accessories || {})) accessory(id, lib.accessories[id])
      for (const id of Object.keys(frag.moments || {})) moment(id, lib.moments[id])
      routes(Array.isArray(frag.routes) ? frag.routes : [])
      strings(frag, 'fragment')
      shared({ moments: Object.keys(frag.moments || {}), accessories: Object.keys(frag.accessories || {}), finishes: Object.keys(frag.finishes || {}), routes: frag.routes })
      for (const [id, m] of Object.entries(frag.moments || {})) if (!row.groups.includes(m?.group)) bad(`moments.${id}`, `${row.prefix} moments belong to ${row.groups.join(' or ')}`)
    },
  }
}

function report(list, label) {
  const lines = list.map((p) => `${p.at}: ${p.msg}`)
  if (lines.length) assert.fail(`${label ? `${label}. ` : ''}${lines.length} problem(s):\n  ${lines.join('\n  ')}`)
}

if (!fragmentFile) {
  test('route table', async (t) => {
    const { route } = await import(playerUrl)
    for (const c of table.route) {
      await t.test(c.name, () => {
        const memory = { at: {}, last: {} }
        c.steps.forEach((s, i) => {
          const got = route({ routes: table.routes }, s.signal, s.detail, memory, s.now, () => s.random ?? 0)
          assert.equal(got, s.expect, `step ${i}: ${s.signal} ${JSON.stringify(s.detail ?? {})} at ${s.now ?? 'now'}`)
        })
      })
    }
  })

  test('clock table', async () => {
    const { clock, timeOfDay } = await import(playerUrl)
    assert.equal(typeof clock, 'function', 'companion-player.js exports clock(library, date) (plan §2.4)')
    for (const c of table.clock) {
      assert.deepEqual(clock({ times: table.times }, new Date(c.date)), c.expect, c.date)
      assert.equal(timeOfDay({ times: table.times }, new Date(c.date)), c.expect.time, `timeOfDay ${c.date}`)
    }
  })

  test('hear table', async (t) => {
    const Behaviour = require('./companion.js')._test?.Behaviour
    if (typeof Behaviour?.prototype.hear !== 'function') return t.skip('companion.js Behaviour has no hear(level, now) yet (packet E-M, plan §2.5)')
    for (const c of table.hear) {
      await t.test(c.name, () => {
        const heard = []
        let seen = null
        let b = null
        const look = () => {
          const cue = b?.cue
          if (cue && cue.id !== seen) {
            seen = cue.id
            if (cue.event === 'talking' || cue.event === 'quiet') heard.push(cue.event)
          }
        }
        b = new Behaviour(look)
        b.apply('listening', { mode: 'recording', destination: 'app' })
        look()
        assert.equal(b.robotState, 'input', 'listening puts the robot in input')
        const t0 = Date.now()
        for (const [ms, level] of c.levels) { b.hear(level, t0 + ms); look() }
        assert.deepEqual(heard, c.expect)
      })
    }
  })

  const raw = JSON.parse(fs.readFileSync(libraryFile, 'utf8'))
  const lib = checker(raw)
  lib.library(raw)
  const only = (code) => lib.problems.filter((p) => p.code === code)

  test('library: content rules', () => report(only('rule'), 'plan §2.8'))
  test('library: finishes need no askFirst gate', () => report(only('askFirst'), KNOWN))
  test('library: pose set has no rx', () => report(only('set.rx'), KNOWN))
  test('library: stretch head keyframes put scale after rotate', () => report(only('stretch-order'), KNOWN))
  test('library: routes use live signals only', () => report(only('retired-signal'), KNOWN))
  test('library: headphones, bow, party-hat and nightcap are wearable', () => {
    report(BASE.wear.filter((id) => raw.accessories[id]?.wear !== true).map((id) => ({ at: `accessories.${id}`, msg: 'needs wear: true' })), KNOWN)
  })
  test('library: counts reach 120 moments, 36 accessories, 10 finishes', () => {
    const counted = Object.values(raw.moments).filter((m) => !m.unwired).length
    const short = [
      [counted, 120, 'counted moments (not unwired)'],
      [Object.keys(raw.accessories).length, 36, 'accessories'],
      [Object.keys(raw.finishes).length, 10, 'finishes'],
    ].filter(([n, target]) => n < target).map(([n, target, what]) => ({ at: what, msg: `${n} of ${target}` }))
    report(short, KNOWN)
  })

  test('library: website copies match the app', async (t) => {
    const vendor = path.join(__dirname, 'vendor', 'agent-robot-avatar')
    const files = (dir) => fs.readdirSync(dir, { recursive: true }).filter((f) => fs.statSync(path.join(dir, f)).isFile()).sort()
    const pairs = [
      [libraryFile, path.join(siteRobot, 'companion-moments.json')],
      [path.join(__dirname, 'companion-player.js'), path.join(siteRobot, 'companion-player.js')],
      ...files(vendor).map((f) => [path.join(vendor, f), path.join(siteRobot, 'vendor', 'agent-robot-avatar', f)]),
    ]
    for (const [app, site] of pairs) {
      const name = path.relative(path.join(__dirname, '..', '..'), site)
      await t.test(name, (tt) => {
        if (!fs.existsSync(site)) return tt.skip(`${name} is not there yet (packet W, then MERGE re-copies)`)
        assert.ok(fs.readFileSync(app).equals(fs.readFileSync(site)), `${name} differs from ${path.relative(path.join(__dirname, '..'), app)} (MERGE re-copies it)`)
      })
    }
    const siteVendor = path.join(siteRobot, 'vendor', 'agent-robot-avatar')
    if (fs.existsSync(siteVendor)) {
      const extra = files(siteVendor).filter((f) => !fs.existsSync(path.join(vendor, f)))
      assert.deepEqual(extra, [], 'website vendor folder has files the app does not ship')
    }
  })
} else {
  const base = JSON.parse(fs.readFileSync(libraryFile, 'utf8'))
  const frag = JSON.parse(fs.readFileSync(fragmentFile, 'utf8'))
  const row = PACKETS[frag.packet] ?? Object.values(PACKETS).find((p) => p.prefix === frag.prefix)
  const id = Object.keys(PACKETS).find((k) => PACKETS[k] === row)
  const signals = new Set(Array.isArray(frag.routes) ? frag.routes.map((r) => r?.signal) : [])
  const merged = {
    ...base,
    groups: { ...base.groups, ...frag.groups },
    palette: { ...base.palette, ...frag.palette },
    finishes: { ...base.finishes, ...frag.finishes },
    accessories: { ...base.accessories, ...frag.accessories },
    moments: { ...base.moments, ...frag.moments },
    routes: [...(Array.isArray(frag.routes) ? frag.routes : []), ...base.routes.filter((r) => !signals.has(r.signal))],
  }
  const label = `fragment ${path.basename(fragmentFile)} (${id ?? 'unknown packet'})`

  test('fragment shape', () => {
    assert.ok(row, `packet ${JSON.stringify(frag.packet)} / prefix ${JSON.stringify(frag.prefix)} is not a row of plan §2.9`)
    assert.equal(frag.prefix, row.prefix, `${id} uses prefix ${row.prefix}`)
    const problems = []
    const bad = (at, msg) => problems.push({ at, msg })
    for (const k of Object.keys(frag)) if (!['packet', 'prefix', 'groups', 'palette', 'accessories', 'moments', 'routes', 'finishes'].includes(k)) bad(k, 'unknown fragment key')
    for (const k of ['groups', 'palette', 'accessories', 'moments', 'finishes']) if (has(frag, k) && !isObj(frag[k])) bad(k, 'must be an object keyed by id')
    if (!isObj(frag.moments)) bad('moments', 'a fragment has moments')
    if (!Array.isArray(frag.routes)) bad('routes', 'a fragment has a routes list')
    if (has(frag, 'finishes') && id !== 'C5') bad('finishes', 'only C5 adds finishes')
    for (const kind of ['groups', 'palette', 'finishes', 'accessories', 'moments']) {
      for (const key of Object.keys(isObj(frag[kind]) ? frag[kind] : {})) {
        if (has(base[kind], key)) bad(`${kind}.${key}`, 'already in the library: fragments are additive only')
        if (['palette', 'accessories', 'moments'].includes(kind) && !key.startsWith(row.prefix)) bad(`${kind}.${key}`, `starts with ${row.prefix}`)
        if (kind === 'groups' && !row.groups.includes(key)) bad(`groups.${key}`, `${id} only adds the groups ${row.groups.join(', ')}`)
      }
    }
    for (const g of row.groups) if (!has(merged.groups, g)) bad('groups', `${id} declares group ${g}`)
    for (const s of signals) if (!row.signals.includes(s)) bad('routes', `${id} routes only ${row.signals.join(', ')} (has ${s})`)
    report(problems, label)
  })

  test('fragment content rules', () => {
    assert.ok(row, 'see fragment shape')
    const c = checker(merged)
    c.fragment(frag, row)
    report(c.problems, `${label}, plan §2.8`)
  })

  test('fragment targets', () => {
    assert.ok(row, 'see fragment shape')
    const problems = []
    const bad = (at, msg) => problems.push({ at, msg })
    const moments = Object.values(isObj(frag.moments) ? frag.moments : {})
    const accessories = Object.values(isObj(frag.accessories) ? frag.accessories : {})
    const list = Array.isArray(frag.routes) ? frag.routes.filter(isObj) : []
    const counted = moments.filter((m) => !m?.unwired).length
    if (counted < row.moments) bad('moments', `${counted} of ${row.moments} new moments`)
    if (accessories.length < row.accessories) bad('accessories', `${accessories.length} of ${row.accessories} new accessories`)
    if (row.wear && accessories.filter((a) => a?.wear === true).length < row.wear) bad('accessories', `at least ${row.wear} new accessories are wear: true`)
    if (row.finishes && Object.keys(frag.finishes || {}).length < row.finishes) bad('finishes', `${Object.keys(frag.finishes || {}).length} of ${row.finishes} new finishes`)
    const routed = new Set(list.flatMap(targets))
    for (const m of row.owns) if (!routed.has(m)) bad(`moments.${m}`, `${id} routes its existing moment ${m}`)
    if (id === 'C5') for (const [i, r] of list.entries()) if (r.signal === 'ambient' && !(isObj(r.is) && DATE_KEYS.some((k) => has(r.is, k)))) bad(`routes[${i}]`, 'season routes match a month, day or weekday')
    if (id === 'C4') {
      if (!list.some((r) => r.signal === 'poke' && r.atLeast?.count === 5)) bad('routes', 'a poke streak route with atLeast: {count: 5}')
      if (!list.some((r) => r.signal === 'poke' && Array.isArray(r.moments) && r.moments.length > 1)) bad('routes', 'a poke pool route (moments with more than one id)')
      if (!list.some((r) => r.signal === 'fling' && r.atLeast?.speed >= 2400 && targets(r).includes('dizzy'))) bad('routes', 'fling atLeast speed 2400 routes dizzy')
      if (!list.some((r) => r.signal === 'fling' && r.atLeast?.speed >= 1200 && r.atLeast.speed < 2400)) bad('routes', 'a lighter fling route with atLeast speed from 1200 to below 2400')
    }
    report(problems, `${label}, plan §2.9`)
  })
}
