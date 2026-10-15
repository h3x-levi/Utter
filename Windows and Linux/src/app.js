'use strict'

const $ = (sel, root = document) => root.querySelector(sel)
const SURFACE = location.hash.slice(1)
const SVG = 'http://www.w3.org/2000/svg'
const DAY_MS = 86400000
const PROPS = new Set(['value', 'checked', 'disabled', 'selected'])

function h(tag, props, ...kids) {
  const el = document.createElement(tag)
  for (const [k, v] of Object.entries(props || {})) {
    if (v == null || v === false) continue
    if (k === 'class') el.className = v
    else if (k === 'text') el.textContent = v
    else if (k === 'style') el.style.cssText = v
    else if (k.startsWith('on')) el.addEventListener(k.slice(2), v)
    else if (PROPS.has(k)) el[k] = v
    else el.setAttribute(k, v === true ? '' : v)
  }
  for (const kid of kids.flat()) if (kid != null && kid !== false) el.append(kid instanceof Node ? kid : String(kid))
  return el
}

// A path is stroked unless it is listed with 'fill'.
const ICONS = {
  search: 'M7 2.5a4.5 4.5 0 1 0 0 9a4.5 4.5 0 1 0 0-9zM10.4 10.4L13.5 13.5',
  trash: 'M3 4.5h10M6.5 4.5V3h3v1.5M4.5 4.5l.7 9h5.6l.7-9M7 7v4.5M9 7v4.5',
  plus: 'M8 3.5v9M3.5 8h9',
  close: 'M4.5 4.5l7 7M11.5 4.5l-7 7',
  copy: 'M6 6h7v7H6zM3.5 10.5v-7h7',
  paste: 'M12.5 3.5V8a2 2 0 0 1-2 2h-7M6 7.5L3.5 10 6 12.5',
  chevron: 'M6 3.5l4.5 4.5L6 12.5',
  check: 'M3.5 8.5l3 3 6-7',
  doc: 'M4 2.5h5l3 3v8H4zM9 2.5v3h3M6 8.5h4M6 11h4',
  lock: [['M4 7.5h8v6H4z', 'fill'], 'M5.75 7.5V5.5a2.25 2.25 0 0 1 4.5 0v2'],
  record: ['M8 2.5a5.5 5.5 0 1 0 0 11a5.5 5.5 0 1 0 0-11z', ['M8 5.75a2.25 2.25 0 1 0 0 4.5a2.25 2.25 0 1 0 0-4.5z', 'fill']],
  call: [['M6 3a2 2 0 1 0 0 4a2 2 0 1 0 0-4z', 'fill'], ['M2 13.5c0-2.6 1.8-4.2 4-4.2s4 1.6 4 4.2z', 'fill'],
    'M11.2 4.4c.9 1 .9 2.8 0 3.8M13 3c1.6 1.8 1.6 4.8 0 6.6'],
}

function icon(name) {
  const svg = document.createElementNS(SVG, 'svg')
  svg.setAttribute('viewBox', '0 0 16 16')
  svg.setAttribute('class', `icon icon-${name}`)
  svg.setAttribute('aria-hidden', 'true')
  for (const part of [].concat(ICONS[name])) {
    const [d, kind] = Array.isArray(part) ? part : [part]
    const path = document.createElementNS(SVG, 'path')
    path.setAttribute('d', d)
    if (kind === 'fill') path.setAttribute('class', 'filled')
    svg.append(path)
  }
  return svg
}

const pen = (label, onclick, kind = '', extra = {}) =>
  h('button', { class: `pen ${kind}`.trim(), type: 'button', onclick, ...extra }, label)
const inkIcon = (label, content, onclick) =>
  h('button', { class: 'inkIcon', type: 'button', 'aria-label': label, title: label, onclick }, content)

// ---------- state ----------

let S = null
const ui = {
  view: 'everything',
  query: '',
  sel: null,
  wordsTab: 'dictionary',
  settingsTab: 'general',
  wordQuery: '',
  wordDraft: '',
  snippetQuery: '',
  draft: { trigger: '', expansion: '', editing: null, problem: '' },
  transcriptEdit: false,
  renaming: null,
  focusBody: false,
  about: null,
  mics: null,
  undo: null,
}
const notNow = new Set(JSON.parse(localStorage.getItem('utter.notNow') || '[]'))
const pendingEdits = new Map()
const lastSent = new Map()

// ---------- text helpers (mirror the Mac app) ----------

const pad2 = (n) => String(n).padStart(2, '0')
const wordsOf = (text) => (text || '').split(/\s+/).filter(Boolean).length

function noteWords(body) {
  return (body || '').split(/\r\n|\r|\n/)
    .filter((line) => !line.trim().startsWith('#'))
    .map((line) => line.replace(/^\s*\*\*[^*]+:\*\*/, ''))
    .reduce((n, line) => n + wordsOf(line), 0)
}

function derivedTitle(body) {
  const line = (body || '').split(/\r\n|\r|\n/).map((l) => l.trim()).find(Boolean)
  if (!line) return ''
  const title = line.replace(/^#+/, '').trim()
  if (title.length <= 60) return title
  const cut = title.slice(0, 60)
  const space = cut.lastIndexOf(' ')
  return (space > 30 ? cut.slice(0, space) : cut) + '…'
}

const displayTitle = (note) => note.title || derivedTitle(note.body) || 'Untitled note'

function mmss(secs) {
  const s = Math.max(0, Math.round(secs || 0))
  const hrs = Math.floor(s / 3600)
  const mins = Math.floor((s % 3600) / 60)
  return hrs ? `${hrs}:${pad2(mins)}:${pad2(s % 60)}` : `${mins}:${pad2(s % 60)}`
}

function talk(secs) {
  const s = Math.round(secs)
  if (s < 60) return `${s} s`
  if (s < 3600) return s % 60 ? `${Math.floor(s / 60)} min ${s % 60} s` : `${s / 60} min`
  const m = Math.floor((s % 3600) / 60)
  return m ? `${Math.floor(s / 3600)} h ${m} min` : `${Math.floor(s / 3600)} h`
}

function dayStart(date) {
  const d = new Date(date)
  d.setHours(0, 0, 0, 0)
  return d.getTime()
}

function dayTitle(key) {
  const today = dayStart(new Date())
  const yesterday = new Date(today)
  yesterday.setDate(yesterday.getDate() - 1)
  const d = new Date(key)
  if (key === today) return d.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' })
  if (key === yesterday.getTime()) return 'Yesterday'
  const weekday = d.toLocaleDateString('en-US', { weekday: 'long' })
  const month = d.toLocaleDateString('en-US', { month: 'long' })
  const year = d.getFullYear() === new Date().getFullYear() ? '' : ` ${d.getFullYear()}`
  return `${weekday} ${d.getDate()} ${month}${year}`
}

const clock = (date) => date.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' })

function trackTitle(text) {
  const words = (text || '').trim().split(/\s+/).slice(0, 4)
  const out = []
  for (const w of words) {
    out.push(w.replace(/[,.!?;:]+$/, ''))
    if (/[,.!?;:]$/.test(w)) break
  }
  return out.join(' ') || 'Untitled'
}

const talkTime = (secs, words) => (secs > 0 ? secs : Math.max(3, Math.round(words / 2.4)))

const KIND_LABEL = { track: 'Dictation', note: 'Note', meeting: 'Meeting' }

// Every track, note and meeting, oldest first, numbered within its day.
function allItems() {
  const out = []
  for (const e of S.history) {
    out.push({ key: 't:' + e.id, kind: 'track', id: e.id, date: new Date(e.ts), text: e.text, title: e.text,
      secs: talkTime(parseFloat(e.dur), wordsOf(e.text)), app: e.app, entry: e })
  }
  for (const n of S.notes) {
    out.push({ key: 'n:' + n.id, kind: n.source === 'meeting' ? 'meeting' : 'note', id: n.id,
      date: new Date(n.modified), text: n.body, title: displayTitle(n), secs: talkTime(n.recordedSeconds, noteWords(n.body)), note: n })
  }
  out.sort((a, b) => a.date - b.date)
  const perDay = new Map()
  for (const item of out) {
    item.day = dayStart(item.date)
    item.num = (perDay.get(item.day) || 0) + 1
    perDay.set(item.day, item.num)
  }
  return out
}

const VIEW_KIND = { dictations: 'track', notes: 'note', meetings: 'meeting' }

function matches(item) {
  const kind = VIEW_KIND[ui.view]
  if (kind && item.kind !== kind) return false
  const q = ui.query.trim().toLowerCase()
  return !q || `${item.title}\n${item.text}`.toLowerCase().includes(q)
}

function selectedItem() {
  return ui.sel ? allItems().find((i) => i.key === ui.sel) : null
}

function nameSuggestions(limit) {
  const skip = new Set(['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday',
    'january', 'february', 'march', 'april', 'may', 'june', 'july', 'august', 'september', 'october',
    'november', 'december'])
  const have = new Set(S.words.map((w) => w.toLowerCase()))
  const counts = new Map()
  const internal = new Set()
  for (const entry of S.history.slice(0, 100)) {
    const words = entry.text.split(/\s+/)
    words.forEach((raw, i) => {
      const word = raw.replace(/^[^\p{L}]+|[^\p{L}]+$/gu, '')
      if (word.length < 3 || /^I'/.test(word)) return
      const internalCaps = /\p{Ll}\p{Lu}/u.test(word)
      const midSentence = i > 0 && !/[.!?:]$/.test(words[i - 1]) && /^\p{Lu}/u.test(word)
      const key = word.toLowerCase()
      if (!(internalCaps || midSentence) || have.has(key) || skip.has(key) || notNow.has(key)) return
      counts.set(word, (counts.get(word) || 0) + 1)
      if (internalCaps) internal.add(word)
    })
  }
  return [...counts].filter(([w, c]) => internal.has(w) || c >= 2)
    .sort((a, b) => b[1] - a[1]).slice(0, limit).map(([w]) => w)
}

// ---------- shared pieces ----------

function lineField(placeholder, value, oninput, keep, extra = {}) {
  return h('label', { class: 'lineField' }, icon('search'),
    h('input', { type: 'search', placeholder, 'aria-label': placeholder, value, 'data-keep': keep, oninput, ...extra }))
}

function sideHeader(title, hint, level = 'h2') {
  return h('div', { class: 'sideHeader' }, h(level, { text: title }), hint != null && h('span', { class: 'hint', text: String(hint) }))
}

function tape(label, kind = '') {
  const goal = S.settings.companionDictationGoal
  if (!goal && !kind) return null
  if (!goal) return h('div', { class: `tape ${kind}` }, kind === 'recording' && h('span', { class: 'recDot' }), h('span', { class: 'tapeLabel', text: label }))
  const bar = h('div', { class: 'bar' })
  let used = 0
  const today = dayStart(new Date())
  for (const entry of [...S.history].reverse()) {
    if (dayStart(entry.ts) !== today) continue
    const pct = Math.min((wordsOf(entry.text) / goal) * 100, 100 - used)
    if (pct <= 0) break
    const seg = h('span', { class: 'seg' })
    seg.style.width = `${pct}%`
    bar.append(seg)
    used += pct
  }
  return h('div', { class: `tape ${kind}`.trim(), role: 'img', 'aria-label': `${label ? label + ', ' : ''}${S.todayWords} of ${goal} words today` },
    kind === 'recording' && h('span', { class: 'recDot' }), label && h('span', { class: 'tapeLabel', text: label }), bar,
    h('span', { class: 'count', text: `${S.todayWords} / ${goal} words` }))
}

function tapeNote(title, body, action) {
  return h('div', { class: 'tapeNote' }, h('p', { class: 'tnTitle', text: title }), body && h('p', { text: body }), action)
}

async function copyText(text, button) {
  await utter.copy(text)
  if (!button) return
  const was = button.textContent
  button.textContent = 'Copied'
  setTimeout(() => { button.textContent = was }, 700)
}

// ---------- menu and toast ----------

let menuEl = null

function closeMenu() {
  menuEl?.remove()
  menuEl = null
}

function openMenu(anchor, entries, { keepFocus = false } = {}) {
  closeMenu()
  const menu = h('div', { class: 'menu', role: 'menu' })
  for (const entry of entries) {
    if (entry === '-') menu.append(h('hr'))
    else if (!entry.run) menu.append(h('div', { class: 'menuLabel', text: entry.label }))
    else {
      menu.append(h('button', {
        class: 'menuItem', type: 'button', role: 'menuitem', disabled: entry.disabled,
        onmousedown: (e) => e.preventDefault(),
        onclick: () => { closeMenu(); entry.run() },
      }, entry.label))
    }
  }
  document.body.append(menu)
  const r = anchor.getBoundingClientRect()
  const left = Math.min(r.left, window.innerWidth - menu.offsetWidth - 12)
  const below = r.bottom + 6 + menu.offsetHeight < window.innerHeight
  menu.style.left = `${Math.max(12, left)}px`
  menu.style.top = `${below ? r.bottom + 6 : Math.max(12, r.top - 6 - menu.offsetHeight)}px`
  menuEl = menu
  if (!keepFocus) menu.querySelector('button:not(:disabled)')?.focus()
}

let toastTimer = null

function hideToast() {
  $('#toast').classList.remove('show')
  ui.undo = null
}

function showUndo(text, undo) {
  const run = async () => { hideToast(); await undo() }
  $('#toast').replaceChildren(h('span', { text }), pen('Undo', run, 'small'))
  $('#toast').classList.add('show')
  ui.undo = run
  clearTimeout(toastTimer)
  toastTimer = setTimeout(hideToast, 6000)
}

const short = (text) => (text.length > 40 ? text.slice(0, 39).trimEnd() + '…' : text)

// ---------- actions ----------

function show(view) {
  ui.view = view
  ui.transcriptEdit = false
  ui.renaming = null
  closeMenu()
  render()
}

function select(item) {
  if (ui.sel === item?.key) return
  flushEdits()
  ui.sel = item ? item.key : null
  ui.transcriptEdit = false
  ui.renaming = null
  if (item && item.kind !== 'track') utter.setOpenNote?.(item.id)
  render()
}

async function newNote() {
  const note = await utter.createNote({ body: '', source: 'typed' })
  const id = note && typeof note === 'object' ? note.id : note
  if (!id) return
  if (ui.view === 'dictations' || ui.view === 'meetings' || ui.view === 'words' || ui.view === 'settings') ui.view = 'notes'
  ui.query = ''
  ui.sel = 'n:' + id
  ui.focusBody = true
  utter.setOpenNote?.(id)
  render()
}

async function deleteItem(item) {
  if (ui.sel === item.key) ui.sel = null
  if (item.kind === 'track') {
    await utter.deleteTrack(item.id)
    showUndo(`Deleted “${short(trackTitle(item.text))}”`, () => utter.restoreTrack(item.entry))
  } else {
    flushEdits()
    await utter.deleteNote(item.id)
    showUndo(`Deleted “${short(item.title)}”`, () => utter.restoreNote(item.note))
  }
  render()
}

async function trackToNote(item) {
  const note = await utter.trackToNote(item.id)
  const id = note && typeof note === 'object' ? note.id : note
  if (id) {
    ui.sel = 'n:' + id
    render()
  }
}

function queueEdit(id, field, value) {
  const key = `${id}:${field}`
  clearTimeout(pendingEdits.get(key)?.timer)
  const send = () => {
    pendingEdits.delete(key)
    lastSent.set(key, value)
    utter.updateNote(id, field === 'title' ? { title: value, titleIsCustom: value.trim() !== '' } : { body: value })
  }
  pendingEdits.set(key, { send, timer: setTimeout(send, 300) })
}

function flushEdits() {
  for (const { send, timer } of [...pendingEdits.values()]) {
    clearTimeout(timer)
    send()
  }
}

function exportShown(format) {
  const items = allItems().filter(matches).reverse().map((i) => ({
    date: i.date.toISOString(),
    kind: KIND_LABEL[i.kind],
    words: i.kind === 'track' ? wordsOf(i.text) : noteWords(i.text),
    title: i.kind === 'track' ? trackTitle(i.text) : i.title,
    text: i.text,
  }))
  utter.exportItems(format, items)
}

function libraryMenu() {
  const meeting = S.meeting && S.meeting.state !== 'failed'
  return [
    meeting ? { label: 'Stop the meeting', run: () => utter.meeting('stop') } : { label: 'Record a meeting', run: () => utter.meeting('start') },
    '-',
    { label: 'Export what’s shown' },
    { label: 'Markdown', run: () => exportShown('markdown') },
    { label: 'CSV', run: () => exportShown('csv') },
    { label: 'Plain text', run: () => exportShown('text') },
    '-',
    { label: 'What’s New', run: () => utter.showView('whats-new') },
    { label: 'Report an Issue…', run: () => utter.showView('report') },
  ]
}

// ---------- spine ----------

const NAV = [['everything', 'Everything'], ['dictations', 'Dictations'], ['notes', 'Notes'], ['meetings', 'Meetings']]

function renderSpine() {
  const meetings = S.notes.filter((n) => n.source === 'meeting').length
  const counts = {
    everything: S.history.length + S.notes.length,
    dictations: S.history.length,
    notes: S.notes.length - meetings,
    meetings,
    words: S.words.length,
  }
  const item = (view, label) => h('button', {
    class: 'navItem', type: 'button', 'aria-current': ui.view === view ? 'page' : null, onclick: () => show(view),
  }, h('span', { text: label }), counts[view] != null && h('span', { class: 'count', text: String(counts[view]) }))
  const today = new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' })
  $('#spine').replaceChildren(
    ...NAV.map(([view, label]) => item(view, label)),
    h('div', { class: 'navGroup', text: 'Vocabulary' }),
    item('words', 'Words'),
    h('div', { class: 'spacer' }),
    h('div', { class: 'printed', 'aria-hidden': 'true', text: `Utter · ${today}` }),
    item('settings', 'Settings'),
  )
}

// ---------- library ----------

function toolbar(withMenu) {
  return h('header', { class: 'toolbar' },
    pen('New note', newNote, 'ghost'),
    pen('Hands-free', () => utter.handsFree(), 'ghost', { 'aria-pressed': S.dictation === 'handsFree' ? 'true' : 'false' }),
    withMenu && inkIcon('More', '···', (e) => openMenu(e.currentTarget, libraryMenu())),
    lineField('Search what you said', ui.query, (e) => {
      ui.query = e.target.value
      if (!['everything', 'dictations', 'notes', 'meetings'].includes(ui.view)) ui.view = 'everything'
      render()
    }, 'search', { id: 'search' }))
}

function meetingBanner() {
  const m = S.meeting
  if (!m) return null
  const time = h('span', { class: 'mono', 'data-meeting-clock': '' }, mmss(meetingSeconds()))
  const hints = []
  if (m.state === 'recording' && m.othersQuiet) hints.push('Nothing heard from the others yet. Check the call isn’t muted or on a headset Utter can’t hear.')
  if (m.state === 'recording' && m.echo) hints.push('Your mic can hear the call through the speakers. Wear headphones so only your words show as “You”.')
  const parts = {
    recording: ['Recording this meeting', [pen('Stop', () => utter.meeting('stop'), 'fill small'), pen('Pause', () => utter.meeting('pause'), 'small')]],
    paused: ['Paused', [pen('Resume', () => utter.meeting('resume'), 'fill small'), pen('Stop', () => utter.meeting('stop'), 'small')]],
    finishing: ['Finishing the transcript', []],
    failed: [m.problem || 'The meeting stopped recording.', [pen('Try again', () => utter.meeting('start'), 'fill small')]],
  }[m.state] || ['Meeting', []]
  if (m.state === 'paused') hints.push('Nothing is being recorded until you resume.')
  return h('section', { class: 'inkNote banner', role: 'status' },
    h('p', { class: 'bannerTitle' }, h('b', { text: parts[0] }), (m.state === 'recording' || m.state === 'paused') && time),
    ...hints.map((t) => h('p', { text: t })),
    parts[1].length > 0 && h('div', { class: 'actions' }, ...parts[1]))
}

function meetingSeconds() {
  const m = S.meeting
  if (!m) return 0
  return (m.elapsed || 0) + (m.state === 'recording' && m.since ? (Date.now() - m.since) / 1000 : 0)
}

function row(item) {
  const label = item.kind === 'track' ? item.text : item.title
  return h('button', {
    class: `row${ui.sel === item.key ? ' sel' : ''}${item.kind === 'track' ? '' : ' strong'}`,
    type: 'button',
    'data-key': item.key,
    'aria-pressed': ui.sel === item.key ? 'true' : 'false',
    onclick: () => select(item),
    ondblclick: () => item.kind === 'track' && utter.pasteAgain(item.text),
    oncontextmenu: (e) => { e.preventDefault(); select(item); openMenu(e.target.closest('.row') || e.target, rowMenu(item)) },
  }, h('span', { class: 'num', text: pad2(item.num) }), h('span', { class: 'title', text: label }),
  h('span', { class: 'time', text: item.secs ? mmss(item.secs) : '' }))
}

function rowMenu(item) {
  const entries = [{ label: 'Copy', run: () => utter.copy(item.text) }]
  if (item.kind === 'track') {
    entries.push({ label: 'Paste again', run: () => utter.pasteAgain(item.text) }, { label: 'Convert to note', run: () => trackToNote(item) })
  }
  entries.push('-', { label: 'Delete', run: () => deleteItem(item) })
  return entries
}

function side(title, hint, items) {
  return h('div', { class: 'side' }, sideHeader(title, hint, 'h3'), h('div', { class: 'rows' }, ...items.map(row)))
}

function dayBlock(key, dayItems, shown) {
  const isToday = key === dayStart(new Date())
  const secs = dayItems.reduce((n, i) => n + i.secs, 0)
  const tracks = dayItems.length
  let body
  if (ui.view === 'everything') {
    const a = shown.filter((i) => i.date.getHours() < 12)
    const b = shown.filter((i) => i.date.getHours() >= 12)
    body = h('div', { class: 'sides' }, side('Side A', `morning · ${a.length}`, a), side('Side B', `afternoon and evening · ${b.length}`, b))
  } else {
    const title = { dictations: 'Dictations', notes: 'Notes', meetings: 'Meetings' }[ui.view]
    body = h('div', { class: 'side' }, sideHeader(title, shown.length, 'h3'), h('div', { class: 'rows' }, ...shown.map(row)))
  }
  return h('section', { class: `day${isToday ? ' today' : ''}` },
    h('h2', { class: 'dayTitle', text: dayTitle(key) }),
    h('p', { class: 'daySummary', text: `${tracks} ${tracks === 1 ? 'track' : 'tracks'} · ${talk(secs)} of talk${isToday ? ', all on this computer' : ''}` }),
    body)
}

function emptyLibrary() {
  const hold = S.hotkeyLabel || S.settings.hotkeyName || 'the hotkey'
  if (ui.view === 'meetings') {
    return tapeNote('No meetings yet', 'Record a meeting and Utter writes down what you and the others say.',
      pen('Record a meeting', () => utter.meeting('start')))
  }
  if (ui.view === 'notes') return tapeNote('No notes yet', 'Write one here, or press Ctrl+Alt+N to talk into a new note.', pen('New note', newNote))
  return tapeNote('Nothing on this tape yet', `Hold ${hold} and talk; every track lands here.`)
}

function renderLibrary(main) {
  const scroll = h('div', { class: 'scroll', 'data-scroll': 'library-' + ui.view })
  if (S.engine && !S.engine.ready) {
    scroll.append(h('section', { class: 'inkNote', role: 'status' },
      h('p', {}, h('b', { text: S.engine.problem || 'Loading the speech model' })),
      !S.engine.problem && h('p', { text: 'Dictation starts as soon as it is ready.' })))
  }
  scroll.append(meetingBanner() || '')

  const items = allItems()
  const days = new Map()
  for (const item of items) {
    if (!days.has(item.day)) days.set(item.day, [])
    days.get(item.day).push(item)
  }
  const keys = [...days.keys()].sort((a, b) => b - a)
  let any = false
  for (const key of keys) {
    const shown = days.get(key).filter(matches)
    if (!shown.length) continue
    any = true
    scroll.append(dayBlock(key, days.get(key), shown))
  }
  if (!any && ui.query.trim()) {
    scroll.append(tapeNote(`Nothing matches “${ui.query.trim()}”`, 'Utter looks through every track, note and meeting on this computer.'))
  } else if (!any) {
    const today = dayStart(new Date())
    const todays = days.get(today) || []
    const secs = todays.reduce((n, i) => n + i.secs, 0)
    scroll.append(h('section', { class: 'day today' },
      h('h2', { class: 'dayTitle', text: dayTitle(today) }),
      h('p', { class: 'daySummary', text: `${todays.length} tracks · ${talk(secs)} of talk, all on this computer` }),
      emptyLibrary()))
  }
  scroll.append(h('div', { class: 'filler', 'aria-hidden': 'true' }))
  main.append(toolbar(true), tape(), scroll)
}

// ---------- fold ----------

function suggestionCard() {
  const name = nameSuggestions(1)[0]
  if (!name) return null
  return h('section', { class: 'inkNote' },
    h('p', {}, 'Utter heard a new name, ', h('b', { text: name }), '. Add it to Words so it’s always spelled right?'),
    h('div', { class: 'actions' },
      pen('Add to words', () => utter.setWords([...S.words, name]), 'fill small'),
      pen('Not now', () => {
        notNow.add(name.toLowerCase())
        localStorage.setItem('utter.notNow', JSON.stringify([...notNow]))
        render()
      }, 'ghost small')))
}

function emptyFold() {
  const hints = [
    [['↑', '↓'], 'choose a track'], [['Enter'], 'paste it again'], [['Ctrl C'], 'copy'], [['Del'], 'delete'],
    [['Ctrl Z'], 'undo a delete'], [['Ctrl N'], 'new note'], [['Ctrl F'], 'search'], [['Ctrl 1', 'Ctrl 5'], 'switch lists'],
  ]
  return h('div', { class: 'emptyFold' },
    h('p', { class: 'tnTitle', text: 'Choose a track' }),
    h('p', { text: 'It opens here with Paste again and Copy.' }),
    h('div', { class: 'keyHints' }, ...hints.flatMap(([keys, label]) => [
      h('span', { class: 'keys' }, ...keys.map((k) => h('span', { class: 'keycap', text: k }))),
      h('span', { text: label }),
    ])))
}

function trackFold(item) {
  const words = wordsOf(item.text)
  return [
    h('h2', { class: 'foldTitle', text: trackTitle(item.text) }),
    h('p', { class: 'meta', text: `Track ${pad2(item.num)}${item.app ? ` · Into ${item.app}` : ''}\n${clock(item.date)} · ${mmss(item.secs)} · ${words} ${words === 1 ? 'word' : 'words'}` }),
    h('p', { class: 'written', text: item.text }),
    h('div', { class: 'foldActions' },
      pen('Paste again', () => utter.pasteAgain(item.text), 'fill'),
      pen('Copy', (e) => copyText(item.text, e.currentTarget)),
      inkIcon('More', '···', (e) => openMenu(e.currentTarget, [
        { label: 'Convert to note', run: () => trackToNote(item) }, '-', { label: 'Delete', run: () => deleteItem(item) },
      ])),
      inkIcon('Delete', icon('trash'), () => deleteItem(item))),
  ]
}

function transcript(note) {
  const you = (note.speakers && note.speakers.you) || 'You'
  const box = h('div', { class: 'transcript' })
  for (const line of note.body.split(/\r\n|\r|\n/)) {
    if (!line.trim() || /^#\s/.test(line)) continue
    const turn = line.match(/^\*\*(.+?):\*\*\s*(.*)$/)
    box.append(turn
      ? h('div', { class: `turn${turn[1] === you ? ' you' : ''}` }, h('span', { class: 'who', text: turn[1] }), h('p', { text: turn[2] }))
      : h('div', { class: 'turn' }, h('span', { class: 'who' }), h('p', { text: line })))
  }
  if (!box.childElementCount) box.append(h('p', { class: 'written', text: 'Nothing written down yet.' }))
  return box
}

function renameForm(note) {
  const draft = ui.renaming
  const field = (role, label) => h('label', {}, label,
    h('span', { class: 'lineField' }, h('input', {
      type: 'text', value: draft[role], 'data-keep': `rename-${role}`, 'aria-label': `${label} name`,
      oninput: (e) => { draft[role] = e.target.value },
    })))
  const save = async () => {
    const was = note.speakers || { you: 'You', others: 'Others' }
    for (const role of ['you', 'others']) {
      const name = draft[role].trim()
      if (name && name !== was[role]) await utter.renameSpeaker(note.id, role, name)
    }
    ui.renaming = null
    render()
  }
  return h('div', { class: 'rename' }, field('you', 'You'), field('others', 'Others'),
    h('div', { class: 'foldActions' }, pen('Save', save, 'fill small'), pen('Cancel', () => { ui.renaming = null; render() }, 'ghost small')))
}

function noteFold(item) {
  const note = item.note
  const isMeeting = item.kind === 'meeting'
  const words = noteWords(note.body)
  const meta = `Track ${pad2(item.num)} · ${isMeeting ? 'Meeting' : 'Note'}\n${clock(item.date)}${item.secs ? ` · ${mmss(item.secs)}` : ''} · ${words} ${words === 1 ? 'word' : 'words'}`
  const title = h('input', {
    class: 'foldTitle', type: 'text', value: note.title, placeholder: derivedTitle(note.body) || 'Untitled note',
    'aria-label': 'Title', 'data-keep': `title:${note.id}`, 'data-note': note.id, 'data-field': 'title',
    oninput: (e) => queueEdit(note.id, 'title', e.target.value), onblur: flushEdits,
  })
  const showTranscript = isMeeting && !ui.transcriptEdit
  const body = showTranscript ? transcript(note) : h('textarea', {
    class: 'written', value: note.body, 'aria-label': 'Note', placeholder: 'Write here, or dictate into this note.',
    'data-keep': `body:${note.id}`, 'data-note': note.id, 'data-field': 'body', 'data-scroll': `body:${note.id}`,
    oninput: (e) => queueEdit(note.id, 'body', e.target.value), onblur: flushEdits,
  })
  const more = []
  if (isMeeting) {
    more.push({ label: ui.transcriptEdit ? 'Show transcript' : 'Edit as text', run: () => { ui.transcriptEdit = !ui.transcriptEdit; render() } })
    more.push({ label: 'Rename speakers…', run: () => { ui.renaming = { ...(note.speakers || { you: 'You', others: 'Others' }) }; render() } })
    more.push('-')
  }
  more.push({ label: 'Delete', run: () => deleteItem(item) })
  return [
    title,
    h('p', { class: 'meta', text: meta }),
    ui.renaming ? renameForm(note) : null,
    body,
    h('div', { class: 'foldActions' },
      pen('Copy', (e) => copyText(note.body, e.currentTarget)),
      inkIcon('More', '···', (e) => openMenu(e.currentTarget, more)),
      inkIcon('Delete', icon('trash'), () => deleteItem(item))),
  ]
}

function renderFold() {
  const fold = $('#fold')
  if (ui.view === 'words' || ui.view === 'settings') return fold.replaceChildren()
  const item = selectedItem()
  if (ui.sel && !item && !ui.focusBody) ui.sel = null
  if (!item) return fold.replaceChildren(suggestionCard() || '', emptyFold())
  const parts = item.kind === 'track' ? trackFold(item) : noteFold(item)
  fold.replaceChildren(...parts.filter(Boolean), item.kind === 'track' ? suggestionCard() || '' : '')
  if (ui.focusBody && item.kind !== 'track') {
    ui.focusBody = false
    fold.querySelector('textarea')?.focus()
  }
}

// ---------- words ----------

const VOICE_COMMANDS = [
  ['delete that', 'Undo the last thing typed (Ctrl+Z). “Undo that” works too.'],
  ['select all', 'Select everything in the text box (Ctrl+A).'],
  ['new line', 'Press Enter.'],
  ['new paragraph', 'Press Enter twice.'],
  ['go to end', 'Jump to the end of the text (Ctrl+End).'],
  ['copy that', 'Copy the selection (Ctrl+C).'],
  ['paste that', 'Paste (Ctrl+V).'],
  ['new note', 'Start a new note and keep talking into it.'],
  ['continue the note', 'Add what you say next to the open note.'],
]

const PACK = [{ trigger: 'my sign', expansion: 'Best regards,' }, { trigger: 'insert date', expansion: '[date] [time]' }]
const PLACEHOLDERS = ['[date]', '[time]', '[datetime]', '[day]', '[clipboard]']

function addWord(raw) {
  const word = raw.trim()
  if (!word || S.words.some((w) => w.toLowerCase() === word.toLowerCase())) return false
  utter.setWords([...S.words, word])
  return true
}

function dictionaryTab() {
  const q = ui.wordQuery.trim().toLowerCase()
  const words = S.words.filter((w) => !q || w.toLowerCase().includes(q))
  const add = h('label', { class: 'addWord' }, icon('plus'), h('input', {
    type: 'text', placeholder: 'Add a word', 'aria-label': 'Add a word', value: ui.wordDraft, 'data-keep': 'add-word',
    oninput: (e) => { ui.wordDraft = e.target.value },
    onkeydown: (e) => {
      if (e.key !== 'Enter') return
      if (addWord(e.target.value)) ui.wordDraft = ''
      e.target.value = ui.wordDraft
    },
  }))
  const suggestions = nameSuggestions(6)
  return [
    h('section', { class: 'wordsSection' },
      sideHeader('Your dictionary', `${S.words.length} ${S.words.length === 1 ? 'word' : 'words'}`),
      h('p', { class: 'detail', text: 'Utter spells these your way.' }),
      h('div', { class: 'toolsRow' },
        lineField('Search words', ui.wordQuery, (e) => { ui.wordQuery = e.target.value; render() }, 'word-search'),
        pen('Copy all', (e) => copyText(S.words.join('\n'), e.currentTarget), 'ghost small', { disabled: !S.words.length })),
      !S.words.length && h('p', { class: 'detail', text: 'No words yet. Add the names and terms Utter gets wrong, and it will spell them your way.' }),
      h('div', { class: 'wordFlow' },
        ...words.map((w) => h('span', { class: 'word' }, h('span', { text: w }),
          h('button', { class: 'x', type: 'button', 'aria-label': `Remove ${w}`, title: 'Remove', onclick: () => utter.setWords(S.words.filter((x) => x !== w)) }, icon('close')))),
        add)),
    suggestions.length > 0 && h('section', { class: 'wordsSection' },
      sideHeader('From your recent dictations', 'click one to add it'),
      h('div', { class: 'wordFlow' }, ...suggestions.map((w) => h('button', { class: 'suggest', type: 'button', onclick: () => addWord(w) }, icon('plus'), w)))),
  ]
}

function saveSnippet() {
  const d = ui.draft
  const trigger = d.trigger.trim()
  const expansion = d.expansion
  if (!trigger || !expansion.trim()) return
  const clash = S.snippets.find((s) => s.trigger.toLowerCase() === trigger.toLowerCase() && s !== d.editing)
  if (clash) {
    d.problem = `You already have a snippet for “${trigger}”.`
    return render()
  }
  const next = d.editing ? S.snippets.map((s) => (s === d.editing ? { trigger, expansion } : s)) : [...S.snippets, { trigger, expansion }]
  ui.draft = { trigger: '', expansion: '', editing: null, problem: '' }
  utter.setSnippets(next)
  render()
}

function snippetsTab() {
  const d = ui.draft
  const q = ui.snippetQuery.trim().toLowerCase()
  const list = S.snippets.filter((s) => !q || `${s.trigger}\n${s.expansion}`.toLowerCase().includes(q))
  const field = (key, placeholder) => h('label', { class: 'lineField' }, h('input', {
    type: 'text', placeholder, 'aria-label': placeholder, value: d[key], 'data-keep': `snippet-${key}`,
    oninput: (e) => { d[key] = e.target.value; d.problem = ''; syncAddButton() },
    onkeydown: (e) => e.key === 'Enter' && saveSnippet(),
  }))
  const insert = (e) => openMenu(e.currentTarget, PLACEHOLDERS.map((p) => ({
    label: p,
    run: () => {
      const input = document.querySelector('[data-keep="snippet-expansion"]')
      const at = document.activeElement === input ? input.selectionStart : d.expansion.length
      d.expansion = d.expansion.slice(0, at) + p + d.expansion.slice(at)
      render()
      const again = document.querySelector('[data-keep="snippet-expansion"]')
      again.focus()
      again.setSelectionRange(at + p.length, at + p.length)
    },
  })), { keepFocus: true })
  const addPack = (e) => openMenu(e.currentTarget, PACK.map((s) => ({
    label: `${s.trigger}: ${s.expansion}`,
    disabled: S.snippets.some((x) => x.trigger.toLowerCase() === s.trigger),
    run: () => utter.setSnippets([...S.snippets, s]),
  })))
  return [h('section', { class: 'wordsSection' },
    sideHeader('Snippets', S.snippets.length),
    h('p', { class: 'detail', text: 'Say a short phrase and Utter types the full text. Placeholders like [date] and [clipboard] are filled in when it runs.' }),
    h('div', { class: 'toolsRow' },
      lineField('Search snippets', ui.snippetQuery, (e) => { ui.snippetQuery = e.target.value; render() }, 'snippet-search'),
      pen('Add a pack', addPack, 'ghost small')),
    h('div', { class: 'snippetEditor' }, field('trigger', 'When I say'), field('expansion', 'Type this'),
      h('button', { class: 'pen ghost small', type: 'button', onmousedown: (e) => e.preventDefault(), onclick: insert }, 'Insert'),
      pen(d.editing ? 'Save' : 'Add', saveSnippet, 'fill small', { id: 'snippet-add', disabled: !d.trigger.trim() || !d.expansion.trim() })),
    d.problem && h('p', { class: 'problem', role: 'alert', text: d.problem }),
    h('div', { class: 'rows' }, ...list.map((s) => h('div', { class: `snippetRow${d.editing === s ? ' editing' : ''}` },
      h('button', { class: 'trigger', type: 'button', title: 'Edit', text: `“${s.trigger}”`, onclick: () => { ui.draft = { trigger: s.trigger, expansion: s.expansion, editing: s, problem: '' }; render() } }),
      h('span', { class: 'expansion', text: s.expansion }),
      inkIcon(`Remove ${s.trigger}`, icon('close'), () => utter.setSnippets(S.snippets.filter((x) => x !== s)))))))]
}

function syncAddButton() {
  const add = document.getElementById('snippet-add')
  if (add) add.disabled = !ui.draft.trigger.trim() || !ui.draft.expansion.trim()
}

function commandsTab() {
  const on = S.settings.voiceCommands
  return [h('section', { class: 'wordsSection' },
    sideHeader('Voice commands', on ? 'on' : 'off'),
    h('p', { class: 'detail', text: on
      ? 'Say one of these on its own, or at the end of what you say, and Utter does it instead of typing the words.'
      : 'Voice commands are off, so Utter types these words. Turn them on in Settings, Speech.' }),
    h('div', { class: 'rows' }, ...VOICE_COMMANDS.map(([phrase, what]) =>
      h('div', { class: 'commandRow' }, h('b', { text: `“${phrase}”` }), h('span', { text: what })))))]
}

function renderWords(main) {
  const tabs = [['dictionary', 'Dictionary', S.words.length], ['snippets', 'Snippets', S.snippets.length], ['commands', 'Voice commands', VOICE_COMMANDS.length]]
  const content = { dictionary: dictionaryTab, snippets: snippetsTab, commands: commandsTab }[ui.wordsTab]()
  main.append(toolbar(false), h('div', { class: 'scroll', 'data-scroll': 'words' }, h('div', { class: 'page' },
    h('h1', { class: 'display', text: 'Words' }),
    h('p', { class: 'lede', text: 'Names and terms Utter should always hear right, short phrases that expand as you speak, and commands you can say instead of typing.' }),
    h('div', { class: 'chips', role: 'tablist' }, ...tabs.map(([id, label, n]) => h('button', {
      class: 'chip', type: 'button', role: 'tab', 'aria-selected': ui.wordsTab === id ? 'true' : 'false',
      onclick: () => { ui.wordsTab = id; render() },
    }, label, h('span', { class: 'n', text: String(n) })))),
    ...content.filter(Boolean))))
}

// ---------- settings ----------

let micTest = null

function stopMicTest() {
  if (!micTest) return
  cancelAnimationFrame(micTest.raf)
  micTest.stream.getTracks().forEach((t) => t.stop())
  micTest.ctx.close()
  micTest = null
}

async function startMicTest() {
  stopMicTest()
  const id = S.settings.microphoneUID
  let stream
  try {
    stream = await navigator.mediaDevices.getUserMedia({ audio: id ? { deviceId: { exact: id } } : true })
  } catch {
    const db = document.querySelector('[data-meter] .db')
    if (db) db.textContent = 'No mic'
    return
  }
  const ctx = new AudioContext()
  const analyser = ctx.createAnalyser()
  analyser.fftSize = 1024
  ctx.createMediaStreamSource(stream).connect(analyser)
  const data = new Float32Array(analyser.fftSize)
  micTest = { stream, ctx, raf: 0 }
  const tick = () => {
    analyser.getFloatTimeDomainData(data)
    const rms = Math.sqrt(data.reduce((n, v) => n + v * v, 0) / data.length)
    const db = Math.max(-60, 20 * Math.log10(rms || 1e-6))
    const meter = document.querySelector('[data-meter]')
    if (meter) {
      meter.querySelector('.fill').style.width = `${Math.min(1, Math.max(0, (db + 50) / 45)) * 100}%`
      meter.querySelector('.db').textContent = `${Math.round(db)} dB`
    }
    micTest.raf = requestAnimationFrame(tick)
  }
  tick()
  render()
}

async function loadMics() {
  try {
    const devices = await navigator.mediaDevices.enumerateDevices()
    ui.mics = devices.filter((d) => d.kind === 'audioinput' && d.deviceId !== 'default' && d.deviceId !== 'communications')
  } catch {
    ui.mics = []
  }
  if (ui.view === 'settings') render()
}

navigator.mediaDevices?.addEventListener?.('devicechange', loadMics)

function setSetting(key, value) {
  S.settings[key] = value
  utter.setSetting(key, value)
  render()
}

function toggle(key, label) {
  return h('label', { class: 'switch' },
    h('input', { type: 'checkbox', role: 'switch', checked: !!S.settings[key], 'aria-label': label, onchange: (e) => setSetting(key, e.target.checked) }),
    h('span', { class: 'track' }, h('span', { class: 'knob' })))
}

function choice(key, options, label) {
  return h('div', { class: 'choice', role: 'group', 'aria-label': label }, ...options.map(([value, text]) => h('button', {
    type: 'button', 'aria-pressed': S.settings[key] === value ? 'true' : 'false', onclick: () => setSetting(key, value),
  }, text)))
}

const srow = (title, detail, control) => h('div', { class: 'sRow' },
  h('div', { class: 'sText' }, h('div', { class: 'sTitle', text: title }), detail && h('div', { class: 'sDetail', text: detail })),
  control)
const section = (title, hint, ...rows) => h('section', { class: 'sSection' }, sideHeader(title, hint), ...rows)
const value = (text) => h('span', { class: 'mono value', text: String(text) })
const keys = (...names) => h('span', { class: 'keys' }, ...names.map((k) => h('span', { class: 'keycap', text: k })))

const PLATFORM_NAME = { win32: 'Windows', linux: 'Linux', darwin: 'macOS' }
const osName = () => PLATFORM_NAME[S?.platform || utter.platform] || 'your system'
const NO_AI = 'Needs Apple Intelligence, which is only on a Mac.'

function status(text, kind = '') {
  return h('span', { class: `status ${kind}`.trim() }, kind === 'ok' && icon('check'), kind === 'warn' && h('span', { class: 'dot' }), text)
}

function offToggle(label) {
  return h('label', { class: 'switch off' },
    h('input', { type: 'checkbox', role: 'switch', disabled: true, 'aria-label': label }),
    h('span', { class: 'track' }, h('span', { class: 'knob' })))
}

function accountSection() {
  const account = S.account
  return section('Account', 'your Google account', account
    ? srow(account.name || 'Signed in', account.email, pen('Sign out', () => utter.signOut(), 'small'))
    : srow('Not signed in', 'Google sign-in isn’t connected yet.', pen('Sign in', () => openOverlay('sign-in'), 'small')))
}

function crashSection() {
  const logs = (ui.crashes || []).slice(0, 10)
  const when = (date) => new Date(date).toLocaleString('en-US', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })
  const report = (log) => {
    localStorage.setItem('utter.report', JSON.stringify({ category: 'bug', crash: `${log.reason || 'Crash'}\n${when(log.date)}  version ${log.version || '?'}` }))
    utter.showView('report')
  }
  return section('Crash reports', 'the ten most recent',
    S.crashed && srow('Utter’s last run ended in a crash', 'The newest report below is from that run.', status('Crashed', 'warn')),
    !logs.length && srow('Utter hasn’t crashed on this computer.', 'If it ever does, the report appears here.', status('None', 'ok')),
    ...logs.map((log) => h('div', { class: 'sRow tall' },
      h('div', { class: 'sText' }, h('div', { class: 'sTitle', text: log.reason || 'Crash' }),
        h('div', { class: 'sMeta mono', text: [when(log.date), log.version && `version ${log.version}`].filter(Boolean).join('  ') })),
      h('div', { class: 'actions' },
        pen('Report', () => report(log), 'fill small'),
        pen('Show', () => utter.showCrashFolder(), 'ghost small'),
        pen('Copy', (e) => copyText(`${log.reason || 'Crash'}\n${when(log.date)}  version ${log.version || '?'}`, e.currentTarget), 'ghost small')))))
}

function generalTab() {
  const hold = S.hotkeyLabel || S.settings.hotkeyName
  const a = ui.about || {}
  const aboutRows = [['Version', a.version], ['Processor', a.processor || a.cpu], ['Memory', a.memory], [osName(), a.os], ['Speech model', a.model]]
  return [
    accountSection(),
    section('Look', 'light or dark',
      srow('Appearance', 'System follows the Light or Dark setting on your computer.',
        choice('appTheme', [['system', 'System'], ['light', 'Light'], ['dark', 'Dark']], 'Appearance')),
      srow('Always show the pill', 'Keep it on screen when you are not dictating.', toggle('alwaysShowPill', 'Always show the pill'))),
    section('App', 'on this computer',
      srow('Open at login', null, toggle('openAtLogin', 'Open at login')),
      srow('Offer to transcribe calls', 'When a Zoom, Teams, Webex, Slack or Discord call starts.', toggle('offerToTranscribeCalls', 'Offer to transcribe calls'))),
    section('Sound', null,
      srow('Dictation sounds', 'A soft sound when listening starts and stops.', toggle('soundsEnabled', 'Dictation sounds')),
      srow('Pause music while dictating', 'So it does not get into the microphone.', toggle('muteMusicWhileDictating', 'Pause music while dictating'))),
    section('Notes', null, srow('When you dictate into Utter', null,
      choice('captureAppendsToOpenNote', [[true, 'Add to open note'], [false, 'New note']], 'When you dictate into Utter'))),
    section('Help', 'something not working?',
      srow('Report an issue', 'Opens a short form that fills in a GitHub issue for you.',
        pen('Report an Issue…', () => utter.showView('report'), 'small')),
      srow('Microphone test', micTest ? `Hold ${hold} and speak. The line moves while Utter hears you.` : `Check that Utter can hear you before you hold ${hold}.`,
        h('div', { class: 'meter', 'data-meter': '' },
          micTest && h('span', { class: 'line' }, h('span', { class: 'fill' })),
          micTest && h('span', { class: 'db', text: '-- dB' }),
          pen(micTest ? 'Stop' : 'Test', () => (micTest ? (stopMicTest(), render()) : startMicTest()), 'small')))),
    crashSection(),
    section('About', 'this computer',
      ...aboutRows.filter(([, v]) => v != null).map(([k, v]) => srow(k, null, value(v))),
      srow('Acknowledgements', 'Utter is built on whisper.cpp (MIT) and OpenAI’s Whisper speech model, Electron (MIT) and Chromium (BSD), uiohook-napi (MIT) and the Nunito typeface (SIL Open Font License 1.1). Their licences are listed in THIRD_PARTY_NOTICES.md, which ships with the source code.', null)),
  ]
}

// The Mac catalogue, by tier; main reports which are installed.
const MODEL_INFO = {
  base: ['Fastest and smallest. Fine for everyday notes, weaker on unusual names.', 'English', 180],
  small: ['Fast and light, English-only. A good default on any computer, including 8 GB machines.', 'English', 395],
  medium: ['Most accurate on technical terms and unusual names, but English-only, so it can struggle with strong or non-native accents. 10× faster than real time.', 'English', 815],
  turbo: ['Best for accented or non-native English. Trained across 99 languages, so it has heard far more pronunciation variation. Slightly weaker than Medium on technical jargon.', 'Many languages', 718],
}

function modelRow(m) {
  const [summary, language, memory] = MODEL_INFO[m.id] || MODEL_INFO[Object.keys(MODEL_INFO).find((k) => (m.file || '').includes(k === 'turbo' ? 'turbo' : `${k}.`))] || ['', 'English', 0]
  const downloading = m.progress != null && !m.installed
  const removable = m.installed && !m.selected && !(m.bundled ?? m.id === 'small')
  const remove = () => {
    if (window.confirm(`Remove ${m.name}?\n\nThis frees about ${m.sizeMB} MB on this computer. Your history and notes stay.`)) utter.removeModel(m.id)
  }
  let action
  if (downloading) {
    action = h('div', { class: 'meter' }, h('span', { class: 'line' }, h('span', { class: 'fill', style: `width:${Math.round(m.progress * 100)}%` })),
      h('span', { class: 'db', text: `${Math.round(m.progress * 100)}%` }))
  } else if (m.selected) action = status('In use', 'ok')
  else if (m.installed) action = h('div', { class: 'actions' }, removable && inkIcon(`Remove ${m.name}`, icon('trash'), remove), pen('Use', () => utter.selectModel(m.id), 'small'))
  else action = pen('Download', () => utter.downloadModel(m.id), 'small')
  return h('div', { class: 'sRow tall' },
    h('div', { class: 'sText' },
      h('div', { class: 'sTitle', text: m.name }),
      summary && h('div', { class: 'sDetail', text: summary }),
      m.problem ? h('div', { class: 'sDetail problem', text: `Download failed. ${m.problem}` })
        : h('div', { class: 'sMeta mono', text: `${language}  ${m.sizeMB} MB${memory ? `  ${memory} MB memory` : ''}` })),
    action)
}

function speechTab() {
  if (!ui.mics) loadMics()
  const mics = ui.mics || []
  const current = S.settings.microphoneUID || ''
  const options = [['', 'System default'], ...mics.map((m, i) => [m.deviceId, m.label || `Microphone ${i + 1}`])]
  if (current && !mics.some((m) => m.deviceId === current)) options.push([current, 'Saved microphone (not connected)'])
  const pick = h('select', { class: 'pick', 'aria-label': 'Record from', onchange: (e) => setSetting('microphoneUID', e.target.value) },
    ...options.map(([id, label]) => h('option', { value: id, selected: id === current, text: label })))
  const models = S.models || []
  const inUse = models.find((m) => m.selected)
  return [
    section('Microphone', 'what Utter listens to',
      srow('Record from', 'Utter uses this microphone when you dictate and in meetings.', pick)),
    section('Engine', 'how Utter hears you',
      srow('Engine', `Best results. Uses the Whisper model, ${inUse?.sizeMB || 190} MB.`,
        h('div', { class: 'choice', role: 'group', 'aria-label': 'Engine' },
          h('button', { type: 'button', 'aria-pressed': 'true' }, 'Accurate'),
          h('button', { type: 'button', disabled: true, title: 'Needs Apple silicon, which is only on a Mac.' }, 'Fast')))),
    models.length > 0 && section('Speech model', 'on this computer', ...models.map(modelRow),
      h('p', { class: 'sNote', text: 'Your voice stays on this computer. Utter goes online only to download a model you choose.' })),
    section('Writing', 'your words stay yours',
      srow('Fix sentence structure', NO_AI, offToggle('Fix sentence structure')),
      srow('Spoken punctuation', 'Say “period” or “comma” to type the mark.', toggle('spokenPunctuation', 'Spoken punctuation')),
      srow('Voice commands', 'Say a command’s name to run it instead of typing it.', toggle('voiceCommands', 'Voice commands')),
      srow('Prefer your dictionary words', 'Helps Utter hear the names and terms in your dictionary.', toggle('speechBiasEnabled', 'Prefer your dictionary words')),
      srow('Match the app', NO_AI, offToggle('Match the app')),
      srow('Read text around the cursor', NO_AI, offToggle('Read text around the cursor'))),
    section('While you talk', null,
      srow('Show words as you speak', 'A rough preview in the pill before the final text.', toggle('livePreviewEnabled', 'Show words as you speak')),
      srow('Keep dictation history', 'A private list of what you dictate, kept on this computer.', toggle('keepHistory', 'Keep dictation history')),
      srow('Language', 'The included model understands English.', value('English'))),
  ]
}

function keyDescription(id) {
  const win = S.platform === 'win32'
  return {
    rightControl: 'The Ctrl key to the right of the space bar.',
    rightOption: 'The Alt key to the right of the space bar. Some keyboards label it AltGr.',
    rightCommand: win ? 'The Windows key to the right of the space bar.' : 'The Super key to the right of the space bar.',
  }[id] || 'Hold it to talk, let go to type.'
}

function shortcutsTab() {
  const hotkeys = S.hotkeys || []
  const name = S.settings.hotkeyName || S.hotkeyLabel
  const pick = hotkeys.length
    ? h('select', { class: 'pick', 'aria-label': 'Hold to talk key', onchange: (e) => setSetting('hotkeyId', e.target.value) },
      ...hotkeys.map((k) => h('option', { value: k.id, selected: k.id === S.settings.hotkeyId, text: k.name })))
    : value(name)
  return [
    section('Dictation', 'hold to talk',
      srow('Hold to talk', keyDescription(S.settings.hotkeyId), pick),
      srow('Double-tap for hands-free', `Press ${name} twice to keep listening without holding it.`,
        toggle('doubleTapHotkeyForHandsFree', 'Double-tap for hands-free')),
      S.platform === 'linux' && h('p', { class: 'sNote', text: 'Hold-to-talk needs an X11 session. On Wayland Utter runs through XWayland and may miss keys typed into Wayland apps.' })),
    section('Other shortcuts', 'anywhere on your computer',
      srow('Hands-free', 'Listens until you press it again or stop talking for 3 seconds.', keys('Ctrl', 'Alt', 'Space')),
      srow('Take a note', null, keys('Ctrl', 'Alt', 'N')),
      srow('Remember', null, keys('Ctrl', 'Alt', 'R'))),
  ]
}

// ---------- Companion (CompanionSettings.swift) ----------

const companionValue = (key) => S.companionSettings?.[key]

let companionLibrary = null
const companionLibraryReady = SURFACE ? null : utter.companion('library').then((lib) => { companionLibrary = lib; render() })

function companionLook() {
  const lib = companionLibrary
  const finish = companionValue('companionFinish')
  const worn = companionValue('companionAccessory')
  return {
    finish: lib && Object.hasOwn(lib.finishes, finish) ? finish : lib?.defaults.finish,
    worn: lib && Object.hasOwn(lib.accessories, worn) && lib.accessories[worn].wear ? worn : '',
  }
}

function setCompanion(key, value) {
  if (S.companionSettings) S.companionSettings[key] = value
  utter.setSetting(key, value)
  render()
}

function ctoggle(key, label) {
  return h('label', { class: 'switch' },
    h('input', { type: 'checkbox', role: 'switch', checked: !!companionValue(key), 'aria-label': label, onchange: (e) => setCompanion(key, e.target.checked) }),
    h('span', { class: 'track' }, h('span', { class: 'knob' })))
}

function cchoice(key, options, label, current = companionValue(key)) {
  return h('div', { class: 'choice', role: 'group', 'aria-label': label }, ...options.map(([value, text]) => h('button', {
    type: 'button', 'aria-pressed': current === value ? 'true' : 'false', onclick: () => setCompanion(key, value),
  }, text)))
}

function cselect(key, options, label, current) {
  return h('select', { class: 'pick', 'aria-label': label, onchange: (e) => setCompanion(key, e.target.value) },
    ...options.map(([value, text]) => h('option', { value, selected: value === current, text })))
}

// A value of 0 reads "off", as on the Mac; the current value is always offered even when it is not a preset.
function cpick(title, key, choices, label, { current = companionValue(key), set = setCompanion } = {}) {
  const values = [...new Set([...choices, 0, current])].sort((a, b) => a - b)
  return h('select', { class: 'pick', 'aria-label': title, onchange: (e) => set(key, Number(e.target.value)) },
    ...values.map((v) => h('option', { value: String(v), selected: v === current, text: v === 0 ? 'Off' : label(v) })))
}

function cfield(key, placeholder, label, width) {
  const field = h('label', { class: 'lineField companionField' }, h('input', {
    type: 'text', placeholder, 'aria-label': label, value: companionValue(key) || '', 'data-keep': `companion-${key}`,
    oninput: (e) => { if (S.companionSettings) S.companionSettings[key] = e.target.value; utter.setSetting(key, e.target.value) },
  }))
  field.style.width = `${width}px`
  return field
}

function focusTimerPick() {
  const focus = companionValue('companionPomodoroFocusMinutes')
  const rest = companionValue('companionPomodoroBreakMinutes')
  const section = (title, key, choices) => [{ label: title }, ...[...new Set([...choices, companionValue(key)])].sort((a, b) => a - b)
    .map((v) => ({ label: `${v === companionValue(key) ? '✓ ' : ''}${v === 0 ? 'Off' : `${v} min`}`, run: () => setCompanion(key, v) }))]
  return h('button', {
    class: 'pick', type: 'button', 'aria-label': 'Focus timer', 'aria-haspopup': 'menu',
    onclick: (e) => openMenu(e.currentTarget, [
      ...section('Focus', 'companionPomodoroFocusMinutes', [0, 15, 20, 25, 30, 45, 50, 60, 90]), '-',
      ...section('Break', 'companionPomodoroBreakMinutes', [0, 5, 10, 15, 20, 30])]),
  }, focus === 0 || rest === 0 ? 'off' : `${focus} min, then ${rest}`)
}

function memoryRow(memory) {
  const done = Boolean(memory.completedAt)
  const due = !done && memory.remindAt
    ? new Date(memory.remindAt * 1000).toLocaleString('en-US', { weekday: 'short', hour: 'numeric', minute: '2-digit' }) : null
  return h('div', { class: `sRow memoryRow${done ? ' done' : ''}` },
    h('div', { class: 'sText' }, h('div', { class: 'sTitle' }, memory.text, done && h('span', { class: 'memoryTick', 'aria-label': 'Done' }, icon('check'))),
      due && h('div', { class: 'sMeta mono', text: due })),
    h('div', { class: 'actions' },
      !done && pen('Done', () => utter.companion('complete', memory.id), 'ghost small', { 'aria-label': `Mark done: ${memory.text}` }),
      inkIcon(`Delete: ${memory.text}`, icon('trash'), () => utter.companion('delete', memory.id))))
}

function companionTab() {
  const view = S.companion || { active: [], completed: [], waiting: 0, notifications: '', today: {} }
  const roundness = companionValue('companionHeadRoundness') ?? 50
  const nearest = [0, 50, 100].reduce((a, b) => (Math.abs(b - roundness) < Math.abs(a - roundness) ? b : a))
  const goal = S.settings.companionDictationGoal
  const words = (S.todayWords || 0).toLocaleString('en-US')
  const goalRow = (title, key, done, choices) => {
    const target = companionValue(key)
    return srow(title, target ? `${(done || 0).toLocaleString('en-US')} of ${target.toLocaleString('en-US')} today` : null,
      cpick(title, key, choices, (v) => `${v.toLocaleString('en-US')} a day`))
  }
  const memories = view.active.length + view.completed.length
  const lib = companionLibrary
  const look = companionLook()
  return [
    h('div', { class: 'companionTop' },
      h('div', { class: 'companionStage', 'data-companion-stage': String(roundness), role: 'img', 'aria-label': 'Your companion' }),
      section('Companion', 'beside the pill',
        srow('Show beside the pill', 'Listens with you and sleeps when you’re idle', ctoggle('companionEnabled', 'Show beside the pill')),
        srow('Size', null, cchoice('companionSize', [['small', 'Small'], ['medium', 'Medium'], ['large', 'Large'], ['huge', 'Huge']], 'Size')),
        srow('Head shape', 'Square to round', cchoice('companionHeadRoundness', [[0, 'Square'], [50, 'Soft'], [100, 'Round']], 'Head shape', nearest)),
        lib && srow('Finish', null, cselect('companionFinish', Object.entries(lib.finishes).map(([id, f]) => [id, f.name]), 'Finish', look.finish)),
        lib && srow('Wears', 'Stays on between moments', cselect('companionAccessory',
          [['', 'Nothing'], ...Object.entries(lib.accessories).filter(([, a]) => a.wear).map(([id, a]) => [id, a.name])], 'Wears', look.worn)),
        srow('Quiet mode', 'Sleeps and holds its reminders', ctoggle('companionQuietMode', 'Quiet mode')),
        srow('Go quiet on its own', 'While you share your screen or record a meeting', ctoggle('companionAutomaticQuietMode', 'Go quiet on its own')))),
    section('Reminders', 'it taps the pill, gently',
      srow('Stretch', null, cpick('Stretch', 'companionStretchMinutes', [15, 20, 30, 45, 60, 90, 120], (v) => `every ${v} min`)),
      srow('Water', null, cpick('Water', 'companionWaterMinutes', [15, 20, 30, 45, 60, 90, 120], (v) => `every ${v} min`)),
      srow('Focus timer', 'Runs when focus and break are both set', focusTimerPick()),
      srow('Reminder sound', null, ctoggle('companionSounds', 'Reminder sound')),
      srow('Your name', 'Used when it reminds you', cfield('companionUserName', 'Optional', 'Your name', 220)),
      srow('Pinned note', 'Shown beside your companion', cfield('companionPinnedMessage', 'Nothing pinned', 'Pinned note', 260)),
      srow('Private reminders', `Say one with Ctrl+Alt+R; it never leaves Utter. ${view.notifications}`,
        h('div', { class: 'actions' }, h('span', { class: 'mono value', text: view.waiting ? `${view.waiting} waiting` : 'none yet' }),
          memories > 0 && pen('Delete all…', () => utter.companion('deleteAll'), 'ghost small danger'))),
      ...view.active.map(memoryRow), ...view.completed.map(memoryRow)),
    section('Daily tape', 'your word goal',
      srow('Tape length', goal > 0 ? `${words} of ${goal.toLocaleString('en-US')} words today` : `${words} words today`,
        cpick('Tape length', 'companionDictationGoal', [250, 500, 1000, 2000, 3000, 5000, 10000], (v) => `${v.toLocaleString('en-US')} words`,
          { current: goal, set: setSetting })),
      srow('Daily goals', 'Water, stretch and focus goals, and a cheer when you reach one', ctoggle('companionGoalsEnabled', 'Daily goals')),
      companionValue('companionGoalsEnabled') && goalRow('Water breaks', 'companionHydrationGoal', view.today.hydration, [2, 4, 6, 8, 10, 12]),
      companionValue('companionGoalsEnabled') && goalRow('Stretches', 'companionStretchGoal', view.today.stretches, [1, 2, 3, 4, 5, 6, 8, 10]),
      companionValue('companionGoalsEnabled') && goalRow('Focus blocks', 'companionFocusGoal', view.today.focusBlocks, [1, 2, 3, 4, 5, 6, 8])),
  ]
}

// The stage robot lives in its own document (it needs inline styles this page's CSP refuses), kept outside the
// re-rendered tree so a render does not reload it, and laid over the stage slot.
let companionStageFrame = null

function placeCompanionStage() {
  const slot = document.querySelector('[data-companion-stage]')
  if (!slot) {
    if (companionStageFrame) companionStageFrame.hidden = true
    return
  }
  if (!companionStageFrame) {
    companionStageFrame = h('iframe', { src: 'companion.html#preview', class: 'companionStageFrame', title: 'Your companion', tabindex: '-1' })
    companionStageFrame.addEventListener('load', () => companionLibraryReady.then(() => {
      companionStageFrame.contentWindow?.postMessage({ library: companionLibrary }, '*')
      placeCompanionStage()
    }))
    document.body.append(companionStageFrame)
  }
  const r = slot.getBoundingClientRect()
  const view = slot.closest('.scroll')?.getBoundingClientRect() || { top: 0, bottom: innerHeight }
  Object.assign(companionStageFrame.style, {
    left: `${r.left}px`, top: `${r.top}px`, width: `${r.width}px`, height: `${r.height}px`,
    clipPath: `inset(${Math.max(0, view.top - r.top)}px 0 ${Math.max(0, r.bottom - view.bottom)}px 0 round 14px)`,
  })
  companionStageFrame.hidden = Boolean(ui.overlay) || r.bottom < view.top || r.top > view.bottom
  companionStageFrame.contentWindow?.postMessage({ roundness: Number(slot.dataset.companionStage), ...companionLook() }, '*')
}

new MutationObserver(placeCompanionStage).observe(document.getElementById('main'), { childList: true })
document.addEventListener('scroll', placeCompanionStage, true)
window.addEventListener('resize', placeCompanionStage)

async function probeMic() {
  ui.micStatus = 'checking'
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
    stream.getTracks().forEach((t) => t.stop())
    ui.micStatus = 'allowed'
  } catch (error) {
    ui.micStatus = error?.name === 'NotFoundError' ? 'missing' : 'blocked'
  }
  render()
}

function micPermission() {
  if (!ui.micStatus) probeMic()
  if (ui.micStatus === 'allowed') return status('Allowed', 'ok')
  if (ui.micStatus === 'missing') return status('No microphone found', 'warn')
  if (ui.micStatus === 'blocked') {
    return S.platform === 'win32'
      ? pen('Open Settings', () => utter.openExternal('ms-settings:privacy-microphone'), 'fill small')
      : status('Blocked', 'warn')
  }
  return status('Checking')
}

function privacyTab() {
  return [
    h('p', { class: 'prose first' }, h('b', { text: 'Everything stays on this computer.' }),
      ' Utter turns your voice into text here. Your audio and your words are not sent anywhere. There is no account and no usage tracking. Utter goes online only to download a speech model you choose.'),
    section('Permissions', S.platform === 'win32' ? 'Windows Settings' : 'system settings',
      srow('Microphone', 'So Utter can hear you.', micPermission())),
    section('Apple Intelligence', 'on device',
      srow('Writing fixes and commands', `${NO_AI} Dictation works without them.`, status('Not supported'))),
    h('p', { class: 'prose' }, h('b', { text: 'Only the words are kept.' }),
      ' While you dictate, the audio is held in memory and thrown away once the words are typed. Meeting recordings save the words to your note, not the audio. The microphone is on only while you dictate or record a meeting.'),
    section('Erase', null,
      srow('Erase everything', 'History, notes, dictionary words, snippets and settings.', pen('Reset Utter…', () => utter.reset(), 'danger small'))),
  ]
}

function renderSettings(main) {
  const tabs = [['general', 'General'], ['speech', 'Speech'], ['shortcuts', 'Shortcuts'], ['companion', 'Companion'], ['privacy', 'Privacy']]
  if (ui.settingsTab === 'general' && !ui.about) {
    ui.about = {}
    utter.about().then((about) => { ui.about = about || {}; if (ui.view === 'settings') render() })
    utter.crashReports?.().then((logs) => { ui.crashes = logs || []; if (ui.view === 'settings') render() }).catch(() => {})
  }
  const content = { general: generalTab, speech: speechTab, shortcuts: shortcutsTab, companion: companionTab, privacy: privacyTab }[ui.settingsTab]()
  main.append(
    h('div', { class: 'settingsTop' }, h('div', { class: 'chips center', role: 'tablist' }, ...tabs.map(([id, label]) => h('button', {
      class: 'chip', type: 'button', role: 'tab', 'data-tab': id, 'aria-selected': ui.settingsTab === id ? 'true' : 'false',
      onclick: () => { ui.settingsTab = id; render() },
    }, label)))),
    tape('Daily tape'),
    h('div', { class: 'scroll', 'data-scroll': 'settings-' + ui.settingsTab }, h('div', { class: 'settings' }, ...content.filter(Boolean))))
}

// ---------- onboarding and sign-in (full-window, like the Mac's own windows) ----------

const HOTKEY_WORDS = { rightControl: ['Ctrl', 'right Ctrl'], rightOption: ['Alt', 'right Alt'] }

function hotkeyWord() {
  const id = S.settings.hotkeyId
  if (id === 'rightCommand') return S.platform === 'win32' ? ['Win', 'right Windows key'] : ['Super', 'right Super']
  return HOTKEY_WORDS[id] || [S.hotkeyLabel || 'Ctrl', S.hotkeyLabel || 'right Ctrl']
}

const STEPS = ['Welcome', 'Permissions', 'Try it']
const onboarding = { step: Math.min(2, Math.max(0, Number(localStorage.getItem('utter.onboardingStep')) || 0)), forward: true, arriving: false,
  typed: '', dictated: false, mic: null, frame: 10, timer: null }

function openOverlay(name) {
  ui.overlay = name
  if (name === 'sign-in') ui.signingIn = false
  render()
}

function closeOverlay() {
  ui.overlay = null
  clearTimeout(onboarding.timer)
  render()
}

function finishOnboarding() {
  utter.finishOnboarding?.()
  S.settings.hasCompletedOnboarding = true
  localStorage.removeItem('utter.onboardingStep')
  closeOverlay()
}

// The welcome demo: key down, eight spoken beats, thinking once let go, then the pill rests.
function playDemo() {
  clearTimeout(onboarding.timer)
  if (matchMedia('(prefers-reduced-motion: reduce)').matches) { onboarding.frame = 10; return }
  onboarding.frame = 0
  const hold = (f) => (f === 0 ? 800 : f <= 8 ? (f === 8 ? 600 : 300) : 1400)
  const next = () => {
    if (ui.overlay !== 'onboarding' || onboarding.step !== 0 || onboarding.frame >= 10) return
    onboarding.timer = setTimeout(() => { onboarding.frame++; render(); next() }, hold(onboarding.frame))
  }
  next()
}

function demoPill(frame) {
  const look = frame <= 8 ? 'listening' : frame === 9 ? 'thinking' : 'hover'
  const level = frame === 0 ? 0.12 : frame <= 8 ? [0.55, 0.8, 0.45, 0.7][frame % 4] : 0
  const shape = [0.45, 0.7, 0.9, 1, 0.9, 0.7, 0.45]
  return h('div', { class: `demoPill ${look}` }, h('span', { class: 'bars' }, ...shape.map((k, i) => h('i', {
    style: `height:${(look === 'listening' ? 3 + 11 * level * k : look === 'hover' ? 2 + 6 * k : 3 + 3 * (i % 3)).toFixed(1)}px`,
  }))), look === 'hover' && icon('lock'))
}

function setupStripe(name, index, count) {
  return h('div', { class: 'setupStripe', 'aria-label': `Step ${index + 1} of ${count}, ${name}` },
    h('span', { class: 'tapeLabel', text: name }),
    h('span', { class: 'steps' }, ...Array.from({ length: count }, (_, i) => h('i', { class: i <= index ? 'on' : '' }))),
    h('span', { class: 'count', text: `${index + 1} / ${count} steps` }))
}

function heading(title, detail) {
  return h('div', { class: 'obHeading' }, h('h1', { class: 'display', text: title }), h('p', { text: detail }))
}

async function grantMic() {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
    stream.getTracks().forEach((t) => t.stop())
    onboarding.mic = true
  } catch {
    onboarding.mic = false
  }
  render()
}

function onboardingView() {
  const [cap, word] = hotkeyWord()
  const step = onboarding.step
  const handsFree = S.settings.doubleTapHotkeyForHandsFree ? 'Double-tap for hands-free.' : 'Ctrl+Alt+Space for hands-free.'
  let body
  if (step === 0) {
    body = h('div', { class: 'obStep' },
      heading('Talk instead of typing', `Hold ${word}, say what you want to write, then let go. Utter types it wherever your cursor is, in any app.`),
      h('div', { class: 'hero', 'aria-hidden': 'true' },
        h('div', { class: `demoKey${onboarding.frame <= 8 ? ' pressed' : ''}`, text: cap }), demoPill(onboarding.frame)))
  } else if (step === 1) {
    const allowed = onboarding.mic === true
    const control = allowed ? status('Allowed', 'ok')
      : onboarding.mic === false
        ? (S.platform === 'win32' ? pen('Open Settings', () => utter.openExternal('ms-settings:privacy-microphone'), 'fill small') : status('Blocked', 'warn'))
        : pen('Grant', grantMic, 'fill small', { 'aria-label': 'Grant Microphone' })
    body = h('div', { class: 'obStep' },
      heading('One quick permission', S.platform === 'win32'
        ? 'Utter needs to hear you. If Windows asks, allow the microphone. If it is switched off, turn on “Let desktop apps access your microphone” and come back.'
        : 'Utter needs to hear you. If your system asks, allow the microphone.'),
      section('Permissions', allowed ? 'all set' : '1 to go',
        srow('Microphone', `Hears you only while you hold ${word}. Your voice stays on this computer.`, control),
        onboarding.mic === false && h('p', { class: 'sNote problem', text: 'Utter couldn’t open the microphone. Check it is plugged in and allowed, then press Grant again.' }),
        onboarding.mic === false && h('div', { class: 'actions' }, pen('Try again', grantMic, 'small'))))
  } else {
    const field = h('textarea', {
      class: 'written practice', rows: 3, value: onboarding.typed, placeholder: 'Your words will appear here.', 'aria-label': 'Practice text box', 'data-keep': 'practice',
      oninput: (e) => {
        const next = e.target.value
        if (next.length - onboarding.typed.length >= 2 && /\S/.test(next)) onboarding.dictated = true
        onboarding.typed = next
        renderOverlayStatus()
      },
    })
    body = h('div', { class: 'obStep' },
      heading('Try it now', `Hold ${word} and say anything. Let go, and your words appear here.`),
      field, h('div', { class: 'obStatus', id: 'obStatus' }, practiceStatus(word, handsFree)))
  }
  const canContinue = step === 1 ? onboarding.mic === true : step === 2 ? onboarding.dictated : true
  const go = (delta) => {
    onboarding.forward = delta > 0
    onboarding.arriving = true
    onboarding.step = step + delta
    localStorage.setItem('utter.onboardingStep', String(onboarding.step))
    render()
    if (onboarding.step === 0) playDemo()
  }
  return h('div', { class: 'setupWindow', role: 'dialog', 'aria-label': 'Set up Utter' },
    h('div', { class: 'windowTitle', text: 'Set up Utter' }),
    setupStripe(STEPS[step], step, STEPS.length),
    h('div', { class: `setupBody${onboarding.arriving ? (onboarding.forward ? ' arriving' : ' arriving back') : ''}` }, body),
    h('div', { class: 'setupBar' },
      pen('Set up later', finishOnboarding, 'ghost'),
      h('span', { class: 'spacer' }),
      step > 0 && pen('Back', () => go(-1)),
      pen(step === 2 ? 'Done' : 'Continue', () => (step === 2 ? finishOnboarding() : go(1)), 'fill', { disabled: !canContinue })))
}

function practiceStatus(word, handsFree) {
  if (onboarding.dictated) return status(`It works. Hold ${word} to talk in any app. ${handsFree}`, 'ok')
  if (onboarding.mic === false) return status('Utter still needs the microphone. Go back to allow it.', 'warn')
  return status('Ready')
}

function renderOverlayStatus() {
  const el = document.getElementById('obStatus')
  if (!el) return
  const [, word] = hotkeyWord()
  el.replaceChildren(practiceStatus(word, S.settings.doubleTapHotkeyForHandsFree ? 'Double-tap for hands-free.' : 'Ctrl+Alt+Space for hands-free.'))
  const done = document.querySelector('.setupBar .pen.fill')
  if (done) done.disabled = !onboarding.dictated
}

// The Google button isn't connected yet, so a test email and Skip get people in for now.
async function signInWithEmail() {
  const email = (ui.email || '').trim()
  if (!/^[^\s@]+@[^\s@]+$/.test(email)) { ui.emailProblem = 'Enter an email address.'; return render() }
  if (await utter.signInEmail(email)) {
    ui.emailMode = false
    ui.emailProblem = null
    return afterSignIn()
  }
  ui.emailProblem = 'That email isn’t set up yet.'
  render()
}

function afterSignIn() {
  closeOverlay()
  if (!S.settings.hasCompletedOnboarding) { openOverlay('onboarding'); playDemo() }
}

async function signIn() {
  ui.signingIn = true
  render()
  try {
    await utter.signIn()
  } finally {
    ui.signingIn = false
    if (S.account) afterSignIn()
    else render()
  }
}

function signInView() {
  const note = ui.signingIn ? status('Finish signing in in your browser.')
    : S.accountProblem ? status(S.accountProblem, 'warn')
      : h('p', { class: 'fine', text: 'Signing in opens your browser. Utter only learns your name, email and photo.' })
  return h('div', { class: 'setupWindow', role: 'dialog', 'aria-label': 'Sign in to Utter' },
    h('div', { class: 'windowTitle', text: 'Sign in to Utter' }),
    h('div', { class: 'setupStripe' }, h('span', { class: 'tapeLabel', text: 'Sign in' })),
    h('div', { class: 'setupBody' }, h('div', { class: 'obStep' },
      heading('Sign in to start', 'Use your Google account so Utter knows it’s you. Your recordings, notes and words stay on this computer.'),
      ...(ui.emailMode ? [
        h('label', { class: 'lineField emailField' }, h('input', {
          type: 'email', placeholder: 'Email address', value: ui.email || '', 'data-keep': 'email', 'aria-label': 'Email address',
          oninput: (e) => { ui.email = e.target.value },
          onkeydown: (e) => { if (e.key === 'Enter') signInWithEmail() },
        })),
        h('div', { class: 'actions' }, pen('Continue', signInWithEmail, 'fill'), pen('Back', () => { ui.emailMode = false; ui.emailProblem = null; render() }, 'ghost')),
        ui.emailProblem && status(ui.emailProblem, 'warn'),
      ] : [
        h('button', { class: 'google', type: 'button', 'aria-label': 'Sign in with Google', disabled: ui.signingIn, onclick: signIn }),
        h('div', { class: 'actions emailChoice' }, pen('Sign in with email', () => {
          ui.emailMode = true
          render()
          setTimeout(() => $('.emailField input')?.focus())
        })),
        note,
      ]))),
    h('div', { class: 'setupBar' },
      h('span', { class: 'spacer' }),
      pen('Skip for now', () => { utter.skipSignIn(); afterSignIn() }, 'ghost')))
}

function renderOverlay() {
  const el = $('#overlay')
  if (!el) return
  if (!ui.overlay) { el.hidden = true; return el.replaceChildren() }
  el.hidden = false
  el.replaceChildren(ui.overlay === 'onboarding' ? onboardingView() : signInView())
  onboarding.arriving = false
  if (!el.contains(document.activeElement)) el.querySelector('.practice')?.focus({ preventScroll: true })
}

// ---------- surfaces in their own windows: hub, report, what's new, call offer ----------

const hub = { query: '', sel: 0, copied: null }
const trackCount = (n) => `${n} track${n === 1 ? '' : 's'}`
const meetingOn = () => S.meeting && S.meeting.state !== 'failed'

function hubItems() {
  return allItems().filter((i) => i.kind === 'track' || noteWords(i.text) > 0).reverse()
}

function setupSentence(problem) {
  return problem === 'Speech model missing' ? 'Download the speech model so Utter can turn speech into text.' : `The speech model didn’t load. ${problem}`
}

const hubAct = {
  paste: (item) => { utter.pasteAgain(item.text); utter.closeWindow() },
  open: (item) => {
    if (item) localStorage.setItem('utter.select', item.key)
    utter.showView(item?.kind === 'meeting' ? 'meetings' : 'library')
    utter.closeWindow()
  },
  copy: (item) => {
    utter.copy(item.text)
    hub.copied = item.key
    renderSurface()
    setTimeout(() => { if (hub.copied === item.key) { hub.copied = null; renderSurface() } }, 1500)
  },
  handsFree: () => { utter.handsFree(); utter.closeWindow() },
  newNote: async () => {
    const note = await utter.createNote({ body: '', source: 'typed' })
    const id = note && typeof note === 'object' ? note.id : note
    if (id) localStorage.setItem('utter.select', 'n:' + id)
    utter.showView('notes')
    utter.closeWindow()
  },
  meeting: () => { utter.meeting(meetingOn() ? 'stop' : 'start'); utter.closeWindow() },
  settings: () => { utter.showView('settings'); utter.closeWindow() },
}

function hubRows() {
  const items = hubItems()
  const today = items.filter((i) => i.day === dayStart(new Date()))
  const q = hub.query.trim().toLowerCase()
  const rows = q ? items.filter((i) => `${i.title}\n${i.text}`.toLowerCase().includes(q)) : today.slice(0, 8)
  hub.sel = Math.min(hub.sel, Math.max(rows.length - 1, 0))
  return { today, rows, searching: !!q }
}

function deckKey(label, glyph, onclick, { on = false, accent = false } = {}) {
  return h('button', { class: `deckKey${on ? ' on' : ''}${accent ? ' accent' : ''}`, type: 'button', 'aria-pressed': on ? 'true' : 'false', onclick },
    icon(glyph), h('span', { text: label }))
}

function hubView() {
  const { today, rows, searching } = hubRows()
  const recording = S.dictation !== 'idle' || S.meeting?.state === 'recording'
  const problem = S.engine?.problem
  const kind = recording ? 'recording' : problem ? 'setup' : 'ready'
  const label = recording ? 'Recording' : problem ? 'One thing left' : `Ready · hold ${S.hotkeyLabel}`
  const secs = today.reduce((n, i) => n + Math.max(1, Math.round(i.secs)), 0)
  const message = S.meeting?.state === 'failed' ? S.meeting.problem : null
  const selected = rows[hub.sel]
  const row = (item, i) => {
    const sel = i === hub.sel
    const trailing = !sel ? h('span', { class: 'time', text: mmss(Math.max(1, Math.round(item.secs))) })
      : item.kind === 'meeting' ? h('span', { class: 'tools' }, inkIcon('Open in Library', icon('chevron'), () => hubAct.open(item)))
        : h('span', { class: 'tools' },
          inkIcon(hub.copied === item.key ? 'Copied' : 'Copy', icon(hub.copied === item.key ? 'check' : 'copy'), () => hubAct.copy(item)),
          inkIcon('Paste again', icon('paste'), () => hubAct.paste(item)))
    return h('div', {
      class: `row${sel ? ' sel' : ''}${item.kind === 'meeting' ? ' strong' : ''}`, role: 'option', 'aria-selected': sel ? 'true' : 'false',
      onmouseenter: () => { if (hub.sel !== i) { hub.sel = i; renderSurface() } }, onclick: () => { hub.sel = i; renderSurface() },
    }, h('span', { class: 'num', text: pad2(item.num) }), h('span', { class: 'title', text: item.kind === 'track' ? item.text : item.title }), trailing)
  }
  const empty = h('div', { class: 'hubEmpty' },
    h('p', { class: 'tnTitle', text: searching ? `Nothing matches “${hub.query.trim()}”` : 'Nothing on today’s tape yet' }),
    h('p', { text: searching ? 'Utter looks through every track, note and meeting on this computer.' : `Hold ${S.hotkeyLabel} and talk; every track lands here.` }))
  return [
    tape(label, kind),
    h('div', { class: 'hubBody' },
      h('div', { class: 'hubHead' },
        h('h2', { text: searching ? 'Found' : `Today, side ${new Date().getHours() >= 12 ? 'B' : 'A'}` }),
        h('span', { class: 'mono', text: searching ? trackCount(rows.length) : `${trackCount(today.length)} · ${Math.floor(secs / 60)} min ${secs % 60} s` })),
      message ? h('p', { class: 'hubMessage', text: message })
        : problem && h('div', { class: 'hubSetup' },
          h('p', {}, h('b', { text: 'One thing left.' }), ` ${setupSentence(problem)}`),
          pen('Set up', hubAct.settings, 'fill small')),
      lineField('Search what you said', hub.query, (e) => { hub.query = e.target.value; hub.sel = 0; renderSurface() }, 'hub-search', { id: 'hub-search', 'data-own': '' }),
      h('div', { class: 'hubList rows', role: 'listbox', 'aria-label': searching ? 'Found' : 'Today’s tracks', 'data-scroll': 'hub' },
        ...(rows.length ? rows.map(row) : [empty])),
      h('div', { class: 'deck' },
        deckKey('Hands-free', 'lock', hubAct.handsFree, { on: S.dictation === 'handsFree' }),
        deckKey('New note', 'doc', hubAct.newNote),
        deckKey(meetingOn() ? 'Stop meeting' : 'Record meeting', 'record', hubAct.meeting, { accent: true })),
      h('div', { class: 'hubFoot' },
        h('button', { class: 'link', type: 'button', onclick: () => hubAct.open() }, 'Open Library', h('span', { class: 'keycap', text: 'Ctrl+Alt+U' })),
        h('span', { class: 'spacer' }),
        h('button', { class: 'link', type: 'button', onclick: hubAct.settings }, 'Settings'),
        inkIcon('More', '···', (e) => openMenu(e.currentTarget, [
          { label: 'What’s New', run: () => { utter.showView('whats-new'); utter.closeWindow() } },
          { label: 'Report an Issue…', run: () => { utter.showView('report'); utter.closeWindow() } },
          '-',
          { label: 'Quit Utter', run: () => utter.quit() },
        ]))),
      h('div', { class: 'hubHints', 'aria-hidden': 'true' },
        h('span', {}, h('span', { class: 'keycap', text: '↑' }), h('span', { class: 'keycap', text: '↓' }), 'choose'),
        h('span', {}, h('span', { class: 'keycap', text: '↵' }), selected?.kind === 'meeting' ? 'open' : 'paste'),
        h('span', {}, h('span', { class: 'keycap', text: 'Ctrl C' }), 'copy'),
        h('span', {}, h('span', { class: 'keycap', text: 'Ctrl O' }), 'open'))),
  ]
}

function hubKey(e) {
  const ctrl = e.ctrlKey || e.metaKey
  const { rows } = hubRows()
  const item = rows[hub.sel]
  if (menuEl) {
    if (e.key === 'Escape') return closeMenu()
    return
  }
  if (e.key === 'Escape') {
    e.preventDefault()
    if (hub.query) { hub.query = ''; return renderSurface() }
    return utter.closeWindow()
  }
  if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
    e.preventDefault()
    hub.sel = Math.max(0, Math.min(rows.length - 1, hub.sel + (e.key === 'ArrowDown' ? 1 : -1)))
    renderSurface()
    return document.querySelector('.hubList .row.sel')?.scrollIntoView({ block: 'nearest' })
  }
  if (e.key === 'Enter' && item) { e.preventDefault(); return item.kind === 'meeting' ? hubAct.open(item) : hubAct.paste(item) }
  if (!ctrl) return
  const k = e.key.toLowerCase()
  if (k === 'c' && item && !String(window.getSelection()) && !(e.target.selectionEnd > e.target.selectionStart)) { e.preventDefault(); return hubAct.copy(item) }
  if (k === 'o') { e.preventDefault(); return hubAct.open() }
  if (k === 'n') { e.preventDefault(); return hubAct.newNote() }
  if (k === ',') { e.preventDefault(); return hubAct.settings() }
  if (k === 'q') { e.preventDefault(); return utter.quit() }
}

const CATEGORIES = [
  ['bug', 'Bug / Crash', 'Something broke', '[Bug]: '],
  ['audio', 'Audio / Mic', 'Microphone or sound', '[Audio]: '],
  ['performance', 'Performance', 'Slow or stuck', '[Performance]: '],
  ['feature', 'Feature Idea', 'An idea', '[Feature]: '],
]
const handoff = JSON.parse(localStorage.getItem('utter.report') || 'null')
if (SURFACE === 'report') localStorage.removeItem('utter.report')
const report = { category: handoff?.category || 'bug', title: '', details: '', steps: '', expected: '', actual: '', crash: handoff?.crash || null, copied: false, about: null }
const category = () => CATEGORIES.find((c) => c[0] === report.category)

function diagnostics() {
  const a = report.about || {}
  const ram = String(a.memory || '').replace(/\s*GB$/, '')
  const model = (S.models || []).find((m) => m.selected)?.id || 'small'
  let lines = ['### System Diagnostics',
    `- **Utter Version**: ${a.version || S.version}`,
    `- **${osName()} Version**: ${a.os || ''}`,
    `- **Hardware**: ${a.processor || a.cpu || 'Unknown processor'}, ${navigator.hardwareConcurrency || '?'} logical processors, ${ram || '?'} GB memory`,
    `- **Active Speech Model**: ${model}`,
    `- **Configured Hotkey**: ${S.settings.hotkeyName || S.hotkeyLabel}`,
    '- **Processing**: Local Whisper inference; Utter does not upload audio or transcript text'].join('\n')
  if (report.crash) lines += `\n\n### Crash Log\n\`\`\`\n${report.crash.slice(0, 1000)}\n\`\`\``
  return lines
}

const fullTitle = () => category()[3] + (report.title || 'Issue Report')

function reportBody() {
  let body = `## ${fullTitle()}\n\n### Category\n${category()[1]}\n\n### Summary / Description\n${report.details || '_No description provided._'}`
  if (report.category !== 'feature') {
    body += `\n\n### Steps to Reproduce\n${report.steps || '1. \n2. \n3. '}\n\n### Expected Behavior\n${report.expected || '_N/A_'}\n\n### Actual Behavior\n${report.actual || '_N/A_'}`
  }
  return body + '\n\n' + diagnostics()
}

// Swift's urlQueryAllowed minus "&=+#", so links match the Mac's byte for byte.
function queryEncode(value) {
  const keep = /[A-Za-z0-9\-._~!$'()*,;:@/?]/
  return Array.from(value).map((c) => (keep.test(c) ? c : [...new TextEncoder().encode(c)].map((b) => '%' + b.toString(16).toUpperCase().padStart(2, '0')).join(''))).join('')
}

const issueURL = () => `https://github.com/h3x-levi/Utter/issues/new?title=${queryEncode(fullTitle())}&body=${queryEncode(reportBody())}`

function openReport() {
  utter.openExternal(issueURL())
  utter.closeWindow()
}

function reportView() {
  if (!report.about) {
    report.about = {}
    utter.about().then((about) => { report.about = about || {}; renderSurface() })
  }
  const app = S.platform === 'win32' ? 'Notepad' : 'Text Editor'
  const field = (label, key, placeholder) => srow(label, null, h('label', { class: 'lineField field' }, h('input', {
    type: 'text', placeholder, 'aria-label': label, value: report[key], 'data-keep': `report-${key}`,
    oninput: (e) => { report[key] = e.target.value },
    onkeydown: (e) => { if (e.key === 'Enter') { e.preventDefault(); openReport() } },
  })))
  const prose = (label, key, placeholder) => h('textarea', {
    class: 'proseField', rows: 3, placeholder, 'aria-label': label, value: report[key], 'data-keep': `report-${key}`,
    oninput: (e) => { report[key] = e.target.value; e.target.rows = Math.min(10, Math.max(3, e.target.value.split('\n').length)) },
  })
  return [
    h('div', { class: 'surfaceScroll', 'data-scroll': 'report' }, h('div', { class: 'reportPage' },
      h('div', { class: 'pageHead' }, h('h1', { class: 'display small', text: 'Report an issue' }),
        h('p', { text: 'Tell us what went wrong or what you would like. You check the report in your browser before anything is sent.' })),
      section('The issue', null,
        h('div', { class: 'sRow kind' }, h('div', { class: 'choice', role: 'group', 'aria-label': 'Kind' }, ...CATEGORIES.map(([id, , label]) => h('button', {
          type: 'button', 'aria-pressed': report.category === id ? 'true' : 'false', onclick: () => { report.category = id; renderSurface() },
        }, label)))),
        field('Summary', 'title', 'Dictation stops after the computer wakes up')),
      section('What happened', null, prose('What happened', 'details', 'A few sentences are plenty')),
      report.category !== 'feature' && section('Steps to reproduce', null,
        prose('Steps to reproduce', 'steps', `1. Hold ${S.hotkeyLabel} in ${app}\n2. Speak\n3. Release`),
        field('You expected', 'expected', `The words appear in ${app}`),
        field('Instead', 'actual', 'The pill stayed on transcribing')),
      section('What gets attached', 'no dictation text or audio', h('pre', { class: 'diagnostics', text: diagnostics() })))),
    h('div', { class: 'sheetBar' },
      pen(report.copied ? 'Copied' : 'Copy Report', () => {
        utter.copy(reportBody())
        report.copied = true
        renderSurface()
        setTimeout(() => { report.copied = false; renderSurface() }, 2000)
      }, 'ghost'),
      h('span', { class: 'spacer' }),
      pen('Cancel', () => utter.closeWindow()),
      pen('Open in Browser', openReport, 'fill')),
  ]
}

const RELEASES = [
  ["1.2.3", "October 2026", ["The companion has over a hundred new moments for dictation, meetings, care reminders, the time of day, the seasons and play", "Choose a finish and an outfit for the companion in Settings", "Speech detection now skips silence and background noise, so less work runs on your computer", "Dictionary words heard as similar sounds, like \"cube or needs\", are written as the word you added"]],
  ["1.1.57", "September 2026", ["Double-tap the hotkey (Fn) to start hands-free dictation without holding it"]],
  ["3.0.40", "August 2026", ["Companion is now organized into native Today, Remember, Rewards, and Customize tabs.", "Type or speak private memories and reminders; review them before saving, edit them later, or erase them all.", "Dictation milestones now unlock companion objects, animations, and original cat sounds without purchases or expiring rewards.", "Pill symbols remain visible on light or dark backgrounds, and the processing pencil now draws a continuous handwriting stroke.", "Memory files recover their previous saved generation after corruption and roll back cleanly when a disk write fails."]],
  ["3.0.39", "August 2026", ["Companion now uses the full settings width instead of a narrow centered form.", "Both pixel cats have longer bodies plus new grooming, rolling, and loaf animations.", "The cat can play with its ball, box, yarn, and cushion by itself, and reacts to double-clicking, tossing, feeding, and brushing.", "Local relationship memory, daily goals, earned animations, window-edge avoidance, and automatic quiet behavior are now available."]],
  ["3.0.38", "August 2026", ["Fixed the standard Settings command and Command-, opening an empty window instead of Utter Settings.", "Settings sections now open at the top instead of inheriting another section’s scroll position.", "Fixed Home activity labels and values collapsing into a centered cluster on wide windows.", "Settings are now written atomically, failures are reported, and an unreadable settings file is preserved for recovery instead of being overwritten."]],
  ["3.0.37", "August 2026", ["Expanded local automatic call detection beyond Zoom and Teams to Webex, Skype, WhatsApp, Signal, Telegram, Viber, RingCentral, GoTo, Jitsi Meet, LINE, WeChat, and KakaoTalk."]],
  ["3.0.36", "August 2026", ["The resting pill’s microphone is now solid black in light themes and solid white in dark themes."]],
  ["3.0.35", "August 2026", ["Fixed automatic meeting offers appearing for browser playback such as YouTube.", "Automatic offers now require an active call in Zoom, Microsoft Teams, FaceTime, Slack, or Discord. Browser meetings can still be started manually from Notes."]],
  ["3.0.32", "August 2026", ["The companion is now a pixel cat. The two Mochi packs and the two code-drawn Persian cats were removed; the bundled characters are Golden Dog, Panda, Pixel Cat (Ginger) and Pixel Cat (Gray).", "An existing selection naming a removed character is migrated to the default pack on first launch and the correction saved, so nobody lands on an empty companion window.", "Fixed: a pixel-art pack whose canvas is larger than the chosen character size was drawn at full canvas size, overflowing the panel that clips it, so the cat was sliced at the window edge while roaming. Only reproduced on a non-Retina display."]],
  ["3.0.15", "August 2026", ["The pill stays visible over any background - its outline no longer matches what is behind it"]],
  ["3.0.14", "August 2026", ["The pencil shows again while transcribing - it was being drawn past the edge of its own frame"]],
  ["3.0.13", "August 2026", ["No more faint empty shape before the pill fills in when you press the hotkey", "The pill no longer stretches open - it is the right width on its first frame", "Removed the phase text from the pill; the pencil is back on its own"]],
  ["3.0.12", "August 2026", ["The note card's rows arrive top-down, and its transcript is finally full-strength instead of footnote grey", "The pill shows which phase it is in - Transcribing, Rewriting, Typing", "The pencil no longer jumps back and erases its own line every 1.4 seconds", "The level meter shows half a second of history instead of a sixth, so it scrolls instead of flickering"]],
  ["3.0.11", "August 2026", ["The pill's colour now crosses smoothly into each state instead of cutting - the snap you saw on every dictation", "The settle animation added two releases ago was never actually running; it does now", "Clicking the hands-free button no longer strands it on screen and kill the long-press", "A long error message can no longer draw the pill wider than its own window"]],
  ["3.0.10", "August 2026", ["The hands-free button no longer retracts while you reach for it", "The button's outline and ring now emerge together on one curve instead of two"]],
  ["3.0.9", "August 2026", ["The pill animates again - it lands at its new size and springs into place, and the note card fills after the shape arrives"]],
  ["3.0.8", "August 2026", ["The hotkey reacts immediately - every press used to freeze the app for 80ms before the pill could draw", "The pale full-size panel behind the pill is gone, and the old glyphs no longer dissolve on top of the note card"]],
  ["3.0.7", "August 2026", ["The pill grows into the note card without the ghosting that got the animation removed before - the glass now keeps one fixed set of bounds and only its outline animates"]],
  ["3.0.6", "August 2026", ["The morph animation is switched back on", "Faster: the speech model is released when idle instead of holding 869 MB, two thirds of it in swap", "The live preview reads the last ten seconds instead of re-transcribing everything every 0.7s", "Sounds and call detection no longer stall the main thread"]],
  ["3.0.5", "August 2026", ["Fixed a crash that could interrupt a meeting recording after about a minute"]],
  ["2.0.87", "August 2026", ["The note card now grows out of the pill when it opens, matching the way it shrinks back when it closes - the card used to be drawn at full size on the first frame, hiding the animation behind it", "The hands-free button is Liquid Glass like the pill, with the same tint and edge, and morphs out of the pill’s edge instead of appearing beside it"]],
  ["2.0.86", "August 2026", ["The hands-free button now pops out beside the pill as its own circular button instead of sitting inside it - the microphone stays centred and the pill never changes size or shifts", "Hovering anywhere on the pill reveals it, and it stays put while you move onto it to click", "The pill grows smoothly into the note card and shrinks back again, without the crash that animation caused in 2.0.84"]],
  ["2.0.85", "August 2026", ["Fixed the crash when starting a note - the smooth pill-to-card animation added in 2.0.84 invalidated the window’s layout mid-display-cycle and AppKit killed the app", "The resting pill is a centred microphone again; the hands-free button appears beside it on hover, as it did before 2.0.84"]],
  ["2.0.84", "August 2026", ["The pill now grows smoothly into the note card and shrinks back into the pill, instead of the card appearing all at once", "The pill is fixed in place - it cannot be dragged, and it no longer shifts sideways when the hands-free button appears", "Hovering anywhere on the pill reveals the hands-free button; the companion’s window no longer covers the pill’s left half", "The stop button stays visible for the whole hands-free recording instead of hiding until you hover", "The companion’s window is now sized to the character instead of being twice as large, so it stops swallowing clicks near the pill"]],
  ["2.0.83", "August 2026", ["The companion now rides inside the note card while you dictate a note, instead of standing beside the pill where it could overlap", "Drag the pill anywhere and it stays - it no longer snaps or jumps after you let go", "The whole pill is hoverable now: the record button appears wherever you point, not only near one end", "No more dead zone - a click beside the pill or the companion passes through to whatever is behind, instead of being swallowed; only the pill and the character take clicks", "A stop button appears on the pill while hands-free is recording, so a click can stop it", "Fixed: the pill was briefly unclickable for a moment right after a note card closed", "New “Keep dictation history” setting - turn it off to stop Utter logging what you dictate", "Dictated text no longer appears in internal debug logs", "The privacy page now states the facts accurately: one optional model download, and Screen Recording used only for meetings", "Reset now names your notes and installed characters before it deletes them", "Removing a downloaded speech model no longer edits the app itself, which could quietly reset your permissions", "Utter now declares its minimum macOS version, so an unsupported system gets a clear message instead of failing silently"]],
  ["2.0.80", "August 2026", ["The companion is larger and easier to read - 52pt instead of 28, so its face and mood register at a glance", "Each character is sized on its own: a tall slim figure reads smaller than a round one at the same height, so it is drawn a little larger", "Characters redrawn from individual poses: consistent size between moods, nothing cropped", "The companion sits on the pill’s line in every mood - the sleeping pose used to hang 8pt below it", "The companion is its own window now: drag it anywhere, independently of the pill, and it stays where you put it", "Four companion sizes to choose from, in the companion settings", "The Dog is now a golden retriever puppy, drawn pose by pose", "Every character now animates at the speed it was drawn for - sleepy was playing 60% too fast, celebrating 33% too slow", "Characters no longer float over the menu bar when the pill sits at the top of the screen", "The four code-drawn characters have been retired; the animated packs are the companions now", "Dictating into a note no longer types into whatever app is in front, and the pill shows when a note is the destination", "Say \"start a new note\" and the next thing you say goes into it - this never worked before", "Starting a meeting now tells you when the microphone could not be opened instead of recording only the other side", "A meeting window that fails to transcribe is retried rather than lost", "The window remembers its size and position again after being closed once", "Onboarding scrolls instead of pushing its buttons off the bottom at larger text sizes", "The installer window shows its background again instead of opening plain white", "Settings follows the theme the moment you change it, instead of when you next reopen it", "Settings and the setup window can be resized, and Settings remembers the size you chose", "The Hotkey settings card now explains hands-free and note dictation, and the voice commands that route into a note", "Hands-free without a chord - while you are dictating, keep the hotkey held and tap Space; the recording carries on after you let go, and the tapped key never reaches the app you are typing into", "Hover the pill and a record button appears; click it to start hands-free, no keyboard needed", "Setup resumes where you left it: granting Screen Recording makes macOS relaunch Utter, which used to send you back to the welcome screen", "“Show in Dock” off now really means no Dock icon - opening a window no longer adds one until you close it again", "No Dock icon flashes at launch any more", "The countdown line along the foot of the pill is gone; hands-free still stops on its own when you stop talking"]],
  ["2.0.72", "August 2026", ["Panda and Dog companions now ship with the app - no setup, available on a fresh install", "Companion art is no longer cropped: full body, including hair, tails and legs", "Your own character packs still work, and override a shipped one of the same name"]],
  ["2.0.68", "August 2026", ["Permissions now survive replacing the app - Utter is signed with a real developer certificate, so macOS keeps your Accessibility, Microphone and Screen Recording grants across updates", "Granting Accessibility takes effect immediately instead of needing a relaunch", "Fixed a crash risk in the microphone path when a recording stopped mid-buffer", "Quitting during transcription no longer hangs", "A meeting that produced no audio from others now says why instead of failing silently", "The companion is fully released when switched off"]],
  ["2.0.66", "August 2026", ["Companion sits fully in view beside the pill and never overlaps it", "Companion moved into the main window, and offered once during setup", "Say “start a new note” or “continue the note” to route dictation by voice", "The note hotkey (Ctrl+Alt+N) is now shown where you would look for it", "Screen Recording for meetings is asked for during setup and listed with the other permissions", "Dictation history scrolls smoothly with a trackpad, however long it gets"]],
  ["2.0.65", "August 2026", ["Notes - dictate straight into Utter with Ctrl+Alt+N instead of into the app in front; notes are searchable, exportable to Markdown, and no longer a single overwritten buffer", "Meeting capture - records both sides of a call and files it as a transcript, labelled You and Others, transcribed on this computer in rolling windows", "AI note actions - summarise, extract action items, clean up dictation, format as a document, or suggest a title, all on-device", "Desktop companion - an animated character beside the pill, with built-in designs or your own APNG sprite packs", "Onboarding now shows the pill working instead of describing it", "Diagnostics - crash reports are readable in Settings, with a link to Apple’s symbolicated report", "Fixed: dictating during a meeting could type the whole meeting into the app in front of you", "Fixed: a transcription hiccup mid-meeting silently discarded 30 seconds of speech", "Fixed: a long meeting grew memory without bound; now flat", "Fixed: crash reports were unreliable exactly when they mattered, and suppressed macOS’s own report", "Fixed: holding the hands-free chord toggled it repeatedly; the Right Control option fired on every Control shortcut", "Fixed: editing a note’s body froze its automatic title for good"]],
  ["2.0.51", "August 2026", ["The sidebar is now fixed - no collapsing, and the toggle button is gone", "New Liquid Glass look for the pill, the window, and every tile", "Softer sounds: redesigned from scratch, not just quieter", "Fixed an unreadable selected row in the sidebar"]],
  ["2.0.16", "July 2026", ["Speech recognition and writing transforms run on this computer. The included Small model works offline; downloading other model weights and app updates require a network connection", "Utter does not upload dictation audio or transcript text and has no account, API-key, or telemetry service", "Dictation is much faster, typically under half a second instead of waiting on a network round trip", "Redesigned interface: a native sidebar, a consistent type scale, real empty states, and a Home screen that shows live status instead of decorative cards", "The floating pill now shows a real microphone level, names what it’s doing (transcribing, rewriting, typing), explains errors instead of just turning red, and shows the hands-free countdown so you can keep talking to cancel it", "Your scratchpad notes are saved instead of being lost when you switch tabs", "Fixed: Clear All Data now clears everything it promises, exports keep their file extension, permission indicators refresh live, and a fresh install follows your macOS appearance"]],
  ["2.0.13", "July 2026", ["Your clipboard is now fully preserved - dictating no longer wipes copied images, rich text, or files, and starting a recording never touches the clipboard when nothing is selected", "New: Spoken punctuation toggle (Settings → Behavior) - say \"period\" or \"comma\" to punctuate. Off by default, and word-aware so phrases like \"a difficult period\" or \"first thing in the morning\" are left alone"]],
  ["2.0.12", "July 2026", ["Custom Dictionary now actually improves your transcriptions - it fixes the spelling and capitalization of your terms (e.g. 'kubernetes' → 'Kubernetes') and corrects close misspellings of distinctive names", "Smarter language handling - the detected language is now shown on each history entry, and forcing a specific language is honored as a strong hint", "History upgrades - re-inject any past transcription into the app you’re using with one click, plus a language tag on each entry", "Fixed AI commands (Translate, Style, Fix, Summarize) corrupting your document when run on selected text in another app", "Failed AI commands now give clear error feedback instead of a silent 'success' chime"]],
  ["2.0.4", "May 2026", ["Hands-free dictation - press Ctrl+Alt+Space (Control+Option+Space) anywhere to start a hands-free recording", "Works from idle, or upgrades an active push-to-talk session into hands-free without losing audio", "Hands-free auto-stops after 3 seconds of silence, or press Ctrl+Alt+Space again to finalize manually", "New 'hands-free' pill state with orange tint and lock icon while locked on", "User-defined commands override built-ins so you can customize behavior", "Optional {{text}} template placeholder for shaping the prompt an AI command uses", "Replace-vs-append toggle controls whether AI output overwrites your selection or appends after the cursor", "Dynamic snippet placeholders - [date], [time], [datetime], [day], [clipboard]", "Click-to-insert chips in the Snippets editor for placeholder discovery", "Static snippets keep working unchanged - placeholders are opt-in per snippet"]],
  ["2.0.1", "April 2026", ["Major UI overhaul - two-column Home with feature cards and history", "5 themes - Default, Midnight, Frost, Ocean, Ember (pill + window)", "Style commands - make it professional/concise/casual/formal on any text", "Works on selected text in any app - not just dictation", "What’s New page with full version history", "Responsive layout - resizes with window", "Theme picker in Settings with live preview", "Custom menu bar icon"]],
  ["1.1.3", "April 2026", ["Multiple themes - Default, Midnight, Frost, Ocean, Ember (pill + window)", "What’s New page with version history"]],
  ["1.1.2", "April 2026", ["AI Commands page replacing Style - full guide for voice commands", "Clear All Data confirmation dialog", "Style commands - make it professional/concise/casual/formal", "Works on selected text in any app, not just dictation"]],
  ["1.1.1", "March 2026", ["Context-aware formatting (code, chat, email, document detection)", "Auto-detect language with force option"]],
  ["1.1.0", "March 2026", ["Renamed to Utter with lightbulb icon", "Multi-language support (20 languages)", "Voice commands - keyboard actions (undo, select all, new line)", "Configurable hotkey (Fn, Right Option, Right Command, Right Control)", "Dark/light mode toggle", "History search and export (Markdown, CSV, Text)", "Privacy & Security page", "Custom sounds for recording feedback", "Pill position memory", "Right-click context menu on pill"]],
  ["1.0.0", "March 2026", ["Initial release", "Voice to text with Whisper", "Floating pill UI with recording states", "Menu bar integration", "Transcription history with word count and streak", "Dictionary, Snippets, Scratchpad"]],
]

function whatsNewView() {
  return [h('div', { class: 'surfaceScroll', 'data-scroll': 'whats-new' }, h('div', { class: 'whatsNew' },
    h('div', { class: 'pageHead' }, h('h1', { class: 'display', text: 'What’s new' }),
      h('p', {}, 'You’re running Utter ', h('span', { class: 'mono', text: S.version }))),
    ...RELEASES.map(([version, date, lines]) => h('section', { class: 'release' }, sideHeader(version, date, 'h2'),
      ...lines.map((line) => h('p', { class: 'releaseLine', text: line }))))))]
}

function offerView() {
  const app = S.offer?.app
  const failure = S.meeting?.state === 'failed' ? S.meeting.problem : null
  const accept = async () => {
    await utter.meeting('start')
    const state = await utter.getState()
    if (state.meeting?.state !== 'failed') utter.closeWindow()
  }
  return [h('div', { class: 'offerCard', role: 'dialog', 'aria-label': 'Meeting offer' },
    h('div', { class: 'offerTitle' }, icon('call'), h('span', { text: app ? `You’re in a ${app} call` : 'You’re in a call' })),
    h('p', { class: 'offerCaption', text: 'Nothing is being recorded. Transcribe it into a note?' }),
    S.offer?.speakers && h('p', { class: 'offerTip', text: 'Wear headphones so only your words show as “You”.' }),
    failure && h('p', { class: 'offerFailure', text: failure }),
    h('div', { class: 'actions' }, pen(h('span', { class: 'penIcon' }, icon('record'), 'Transcribe'), accept, 'fill'), pen('Not now', () => utter.dismissOffer(), 'ghost')))]
}

const SURFACES = { hub: hubView, report: reportView, 'whats-new': whatsNewView, offer: offerView }

function renderSurface() {
  if (!S || !SURFACES[SURFACE]) return
  preserving(() => {
    const root = $('#surface')
    root.hidden = false
    root.replaceChildren(...SURFACES[SURFACE]().filter(Boolean))
  })
  if (SURFACE === 'hub' || SURFACE === 'offer') utter.fitWindow(Math.ceil($('#surface').getBoundingClientRect().height))
}

function surfaceKey(e) {
  if (SURFACE === 'hub') return hubKey(e)
  if (e.key === 'Escape') {
    if (menuEl) return closeMenu()
    e.preventDefault()
    if (SURFACE === 'offer') return utter.dismissOffer()
    return utter.closeWindow()
  }
  if (SURFACE === 'report' && (e.ctrlKey || e.metaKey) && e.key === 'Enter') { e.preventDefault(); openReport() }
}

if (SURFACE === 'hub') {
  window.addEventListener('focus', () => {
    hub.query = ''
    hub.sel = 0
    renderSurface()
    $('#hub-search')?.focus()
  })
}

// ---------- render ----------

function render() {
  if (!S) return
  if (SURFACE) return renderSurface()
  if (micTest && !(ui.view === 'settings' && ui.settingsTab === 'general')) stopMicTest()
  preserving(() => {
    document.body.classList.toggle('wide', ui.view === 'words' || ui.view === 'settings')
    renderSpine()
    const main = $('#main')
    main.replaceChildren()
    if (ui.view === 'words') renderWords(main)
    else if (ui.view === 'settings') renderSettings(main)
    else renderLibrary(main)
    renderFold()
    renderOverlay()
  })
}

function preserving(paint) {
  const active = document.activeElement
  const keep = active?.dataset?.keep ? {
    key: active.dataset.keep, value: active.value, start: active.selectionStart, end: active.selectionEnd,
    edit: active.dataset.note ? `${active.dataset.note}:${active.dataset.field}` : null,
  } : null
  const scrolls = {}
  document.querySelectorAll('[data-scroll]').forEach((el) => { scrolls[el.dataset.scroll] = el.scrollTop })
  paint()
  document.querySelectorAll('[data-scroll]').forEach((el) => {
    if (scrolls[el.dataset.scroll] != null) el.scrollTop = scrolls[el.dataset.scroll]
  })
  if (keep) {
    const el = document.querySelector(`[data-keep="${CSS.escape(keep.key)}"]`)
    if (el) {
      if (!el.hasAttribute('data-own') && (!keep.edit || keepTyped(keep.edit, el.value))) el.value = keep.value
      el.focus({ preventScroll: true })
      const end = Math.min(keep.end ?? 0, el.value.length)
      try { el.setSelectionRange(Math.min(keep.start ?? 0, end), end) } catch { /* not a text field */ }
    }
  }
}

// A focused note field keeps the user's text until main has caught up; main wins when it has more (a dictation appended).
function keepTyped(edit, fromMain) {
  if (pendingEdits.has(edit)) return true
  const sent = lastSent.get(edit)
  if (sent === undefined || fromMain === sent) {
    lastSent.delete(edit)
    return false
  }
  return !fromMain.startsWith(sent)
}

// ---------- keyboard ----------

function inTextField(el) {
  return el && (el.tagName === 'TEXTAREA' || el.tagName === 'SELECT' || (el.tagName === 'INPUT' && !['checkbox', 'button'].includes(el.type)))
}

function moveSelection(step) {
  const rows = [...document.querySelectorAll('#main .row')]
  if (!rows.length) return
  const at = rows.findIndex((r) => r.dataset.key === ui.sel)
  const next = rows[at < 0 ? (step > 0 ? 0 : rows.length - 1) : Math.max(0, Math.min(rows.length - 1, at + step))]
  select(allItems().find((i) => i.key === next.dataset.key))
  document.querySelector(`#main .row[data-key="${CSS.escape(next.dataset.key)}"]`)?.scrollIntoView({ block: 'nearest' })
}

document.addEventListener('keydown', (e) => {
  const ctrl = e.ctrlKey || e.metaKey
  if (SURFACE) return surfaceKey(e)
  if (ui.overlay) return
  if (e.key === 'Escape') {
    if (menuEl) return closeMenu()
    if (ui.query && document.activeElement?.id !== 'search') { ui.query = ''; return render() }
    return
  }
  if (menuEl && (e.key === 'ArrowDown' || e.key === 'ArrowUp')) {
    const items = [...menuEl.querySelectorAll('button:not(:disabled)')]
    const at = items.indexOf(document.activeElement)
    items[(at + (e.key === 'ArrowDown' ? 1 : -1) + items.length) % items.length]?.focus()
    return e.preventDefault()
  }
  if (ctrl && !e.altKey) {
    const views = { 1: 'everything', 2: 'dictations', 3: 'notes', 4: 'meetings', 5: 'words' }
    if (views[e.key]) { e.preventDefault(); return show(views[e.key]) }
    if (e.key === ',') { e.preventDefault(); return show('settings') }
    if (e.key.toLowerCase() === 'n') { e.preventDefault(); return newNote() }
    if (e.key.toLowerCase() === 'f') {
      e.preventDefault()
      if (ui.view === 'words' || ui.view === 'settings') show('everything')
      return $('#search')?.focus()
    }
  }
  if (inTextField(document.activeElement)) return
  const item = selectedItem()
  if (ctrl && e.key.toLowerCase() === 'z' && ui.undo) { e.preventDefault(); return ui.undo() }
  if (ctrl && e.key.toLowerCase() === 'c' && item && !String(window.getSelection())) { e.preventDefault(); return utter.copy(item.text) }
  if (ui.view === 'words' || ui.view === 'settings') return
  if (e.key === 'ArrowDown' || e.key === 'ArrowUp') { e.preventDefault(); return moveSelection(e.key === 'ArrowDown' ? 1 : -1) }
  if (e.key === 'Enter' && item?.kind === 'track' && !e.target.closest?.('button:not(.row)')) { e.preventDefault(); return utter.pasteAgain(item.text) }
  if ((e.key === 'Delete' || e.key === 'Backspace') && item) { e.preventDefault(); return deleteItem(item) }
})

document.addEventListener('mousedown', (e) => {
  if (menuEl && !menuEl.contains(e.target)) closeMenu()
})

window.addEventListener('blur', closeMenu)
window.addEventListener('beforeunload', flushEdits)

setInterval(() => {
  const el = document.querySelector('[data-meeting-clock]')
  if (el && S?.meeting?.state === 'recording') el.textContent = mmss(meetingSeconds())
}, 1000)

// ---------- start ----------

if (SURFACE) document.body.classList.add('surface', `surface-${SURFACE}`)

function takeSelection() {
  const key = localStorage.getItem('utter.select')
  if (!key) return
  localStorage.removeItem('utter.select')
  ui.sel = key
  ui.query = ''
  ui.focusBody = key.startsWith('n:')
}

utter.onState((state) => { S = state; render() })
utter.onShow((view) => {
  if (view === 'onboarding' || view === 'sign-in') {
    openOverlay(view)
    if (view === 'onboarding') playDemo()
    return
  }
  if (ui.overlay) closeOverlay()
  takeSelection()
  if (view === 'companion') ui.settingsTab = 'companion'
  show({ library: 'everything', companion: 'settings' }[view] || view)
})
utter.getState().then((state) => {
  S = state
  if (!SURFACE && !state.account && !state.signInSkipped) ui.overlay = 'sign-in'
  else if (!SURFACE && !state.settings.hasCompletedOnboarding) {
    ui.overlay = 'onboarding'
    if (onboarding.step === 0) playDemo()
  }
  if (!SURFACE) takeSelection()
  render()
})
