// Text rules ported from the Mac app, so both apps write the same words and files.

const RATE = 16000

function isUsable(text) {
  const trimmed = (text || '').trim()
  if (!trimmed || trimmed.toUpperCase() === '[BLANK_AUDIO]') return false
  return trimmed.replace(/\[[^\]]*\]|\([^)]*\)/g, '').replace(/^[\s\p{P}]+|[\s\p{P}]+$/gu, '') !== ''
}

const SENTENCE_START = '(?:^|(?<=[.!?:]\\s)|(?<=\\n))'
const LISTS = [
  ['first,\\s*', '\n1. '], ['number one,?\\s+', '\n1. '],
  ['second,\\s*', '\n2. '], ['number two,?\\s+', '\n2. '],
  ['third,\\s*', '\n3. '], ['number three,?\\s+', '\n3. '],
  ['fourth,\\s*', '\n4. '], ['fifth,\\s*', '\n5. '],
]
const PUNCTUATION = [
  ['\\s+comma,?(?=\\s)', ','],
  ['\\s+period\\.?(?=\\s|$)', '.'],
  ['\\s+full stop\\.?(?=\\s|$)', '.'],
  ['\\s+question mark[.?]?(?=\\s|$)', '?'],
  ['\\s+exclamation (?:mark|point)[.!]?(?=\\s|$)', '!'],
  ['\\s+new ?line\\.?(?:\\s+|$)', '\n'],
  ['\\s+colon(?=\\s)', ':'],
  ['\\s+semicolon(?=\\s)', ';'],
]

function formatText(text, spokenPunctuation = false) {
  if (!text) return text
  let result = text
  if (spokenPunctuation) {
    for (const [p, r] of LISTS) result = result.replace(new RegExp(SENTENCE_START + p, 'gi'), r)
    for (const [p, r] of PUNCTUATION) result = result.replace(new RegExp(p, 'gi'), r)
  }
  result = result.replaceAll(' i ', ' I ').replaceAll(" i'", " I'")
  if (result.startsWith('i ')) result = 'I ' + result.slice(2)

  const chars = Array.from(result)
  const isLetter = (c) => /\p{L}/u.test(c)
  if (chars.length && isLetter(chars[0])) chars[0] = chars[0].toUpperCase()
  for (let i = 0; i < chars.length;) {
    if ('.!?'.includes(chars[i])) {
      let j = i + 1
      while (j < chars.length && (chars[j] === ' ' || chars[j] === '\n')) j++
      if (j < chars.length && isLetter(chars[j])) chars[j] = chars[j].toUpperCase()
      i = j
    } else i++
  }
  result = chars.join('').replace(/\n(\d+\.\s*)(\w)/g, (_m, n, c) => '\n' + n + c.toUpperCase())

  if (result.startsWith('\n')) result = result.slice(1)
  return result.replace(/ {2,}/g, ' ').replace(/^[ \t]+|[ \t]+$/g, '')
}

const fuzzyBudget = (length) => (length <= 5 ? 1 : length <= 9 ? 2 : 3)

function levenshtein(a, b) {
  if (a === b) return 0
  const x = Array.from(a), y = Array.from(b)
  let prev = Array.from({ length: y.length + 1 }, (_, i) => i)
  for (let i = 1; i <= x.length; i++) {
    const cur = [i]
    for (let j = 1; j <= y.length; j++) {
      cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (x[i - 1] === y[j - 1] ? 0 : 1))
    }
    prev = cur
  }
  return prev[y.length]
}

function correct(text, words) {
  const canonical = (words || []).map((w) => w.trim()).filter(Boolean)
  if (!canonical.length || !text) return text
  const byLower = new Map(canonical.map((w) => [w.toLowerCase(), w]))
  const len = (s) => Array.from(s).length

  const replace = (token) => {
    const lower = token.toLowerCase()
    if (byLower.has(lower)) return byLower.get(lower)
    if (len(token) < 6) return token
    let best = null, bestDistance = Infinity
    for (const word of canonical) {
      const wl = word.toLowerCase()
      if (len(wl) < 6 || Math.abs(len(wl) - len(lower)) > fuzzyBudget(Math.max(len(wl), len(lower)))) continue
      const d = levenshtein(lower, wl)
      if (d < bestDistance) { bestDistance = d; best = word }
    }
    if (!best || bestDistance > fuzzyBudget(Math.max(len(best), len(token)))) return token
    if (token === token.toUpperCase() && len(token) > 1) return best.toUpperCase()
    if (token[0] !== token[0].toLowerCase()) return best[0].toUpperCase() + best.slice(1)
    return best
  }
  return correctSounds(text.replace(/[\p{L}']+/gu, replace), canonical)
}

// Sound-alike keys: voicing pairs merge and vowels drop, so an accent's "cooper netties" keys like "Kubernetes".
function soundKey(word) {
  const w = word.toLowerCase().normalize('NFD').replace(/[^a-z]/g, '')
    .replace(/^(k|g|p)n/, 'n').replace(/^wr/, 'r').replace(/ph/g, 'f').replace(/th/g, 't')
    .replace(/c(?=[eiy])/g, 's').replace(/x/g, 'ks')
  const map = { c: 'k', q: 'k', g: 'k', b: 'p', d: 't', v: 'f', z: 's', j: 'k' }
  let key = ''
  for (const ch of w) {
    const c = map[ch] || ch
    if ('aeiouhwy'.includes(c) || key.endsWith(c)) continue
    key += c
  }
  return key
}

// Replaces 1-3 word spans that sound like a dictionary word and are spelled close enough to it.
function correctSounds(text, canonical) {
  const targets = canonical.map((w) => ({ w, key: soundKey(w), letters: w.toLowerCase().replace(/[^\p{L}]/gu, '') }))
    .filter((t) => t.key.length >= 4)
  if (!targets.length) return text
  const known = new Set(canonical.map((w) => w.toLowerCase()))
  const tokens = [...text.matchAll(/[\p{L}']+/gu)]
  const out = []
  let cursor = 0
  for (let i = 0; i < tokens.length;) {
    let hit = null
    for (let n = Math.min(3, tokens.length - i); n >= 1 && !hit; n--) {
      const span = tokens.slice(i, i + n)
      const gap = text.slice(span[0].index, span[n - 1].index + span[n - 1][0].length)
      if (n > 1 && /[^\p{L}'\s]/u.test(gap)) continue
      if (span.some((t) => known.has(t[0].toLowerCase()))) continue
      const letters = span.map((t) => t[0]).join('').toLowerCase().replace(/[^\p{L}]/gu, '')
      if (n === 1 && letters.length < 5) continue
      const key = soundKey(letters)
      hit = targets.find((t) => t.key === key && letters !== t.letters
        && letters.length >= t.letters.length * 0.6 && letters.length <= t.letters.length * 1.7
        && levenshtein(letters, t.letters) / Math.max(letters.length, t.letters.length) <= 0.5)
      if (hit) {
        out.push(text.slice(cursor, span[0].index), hit.w)
        cursor = span[0].index + gap.length
        i += n
      }
    }
    if (!hit) i++
  }
  return out.join('') + text.slice(cursor)
}

const escapeRegExp = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')

function expandPlaceholders(expansion, clipboard = '', now = new Date()) {
  const date = now.toLocaleDateString(undefined, { dateStyle: 'long' })
  const time = now.toLocaleTimeString(undefined, { timeStyle: 'short' })
  const values = [
    ['[datetime]', `${date} at ${time}`],
    ['[date]', date],
    ['[time]', time],
    ['[day]', now.toLocaleDateString(undefined, { weekday: 'long' })],
    ['[clipboard]', clipboard],
  ]
  return values.reduce((s, [key, value]) => s.replace(new RegExp(escapeRegExp(key), 'gi'), () => value), expansion)
}

function applySnippets(text, snippets, clipboard, now) {
  let result = text
  for (const { trigger, expansion } of snippets || []) {
    if (!trigger) continue
    const value = expandPlaceholders(expansion || '', clipboard, now)
    result = result.replace(new RegExp(escapeRegExp(trigger), 'gi'), () => value)
  }
  return result
}

const VOICE_COMMANDS = [
  ['delete that', 'undo'], ['undo that', 'undo'], ['select all', 'selectAll'],
  ['new line', 'newLine'], ['new paragraph', 'newParagraph'], ['go to end', 'goToEnd'],
  ['copy that', 'copy'], ['paste that', 'paste'],
  ['start a new note', 'newNote'], ['start new note', 'newNote'], ['new note', 'newNote'],
  ['continue the note', 'continueNote'], ['continue note', 'continueNote'],
]

function voiceCommand(text) {
  const cleaned = text.toLowerCase().trim().replace(/^[.,!?]+|[.,!?]+$/g, '')
  const hit = VOICE_COMMANDS.find(([phrase]) => cleaned === phrase || cleaned.endsWith(phrase))
  return hit ? hit[1] : null
}

function biasPrompt(words) {
  const seen = new Set(), terms = []
  const lead = 'The following transcript may mention ', tail = '.'
  for (const raw of words || []) {
    const term = raw.trim()
    if (term.length < 3 || seen.has(term.toLowerCase())) continue
    if ((lead + [...terms, term].join(', ') + tail).length > 420) break
    seen.add(term.toLowerCase())
    terms.push(term)
  }
  return terms.length ? lead + terms.join(', ') + tail : ''
}

function derivedTitle(body) {
  const first = (body || '').split(/\r\n|[\n\r\u2028\u2029\u0085\v\f]/).find((l) => l.trim())
  if (!first) return ''
  const line = first.trim().replace(/^#+/, '').trim()
  if (line.length <= 60) return line
  const cut = line.slice(0, 60), space = cut.lastIndexOf(' ')
  return (space > 30 ? cut.slice(0, space) : cut) + '…'
}

const displayTitle = (note) => note.title || derivedTitle(note.body) || 'Untitled note'

function turns(segments, gap = 1.2) {
  const out = []
  let start = 0, end = 0, text = '', lastWordEnd = null
  const close = () => { if (text.trim()) out.push({ start, end, text: text.trim() }); text = '' }
  for (const s of segments) {
    if (!s.text.trim()) continue
    if (lastWordEnd !== null && s.start - lastWordEnd >= gap) close()
    if (!text) { start = s.start; end = s.end } else end = Math.max(end, s.end)
    text += s.text
    lastWordEnd = Math.max(lastWordEnd ?? s.end, s.end)
  }
  close()
  return out
}

const wordsOf = (t) => t.toLowerCase().split(/[^\p{L}\p{N}]+/u).filter(Boolean)
const pairsOf = (w) => w.slice(1).map((x, i) => `${w[i]} ${x}`)

function isEcho(mine, theirs) {
  const words = wordsOf(mine)
  if (!words.length) return false
  const heard = wordsOf(theirs)
  if (words.length === 1) return heard.includes(words[0])
  const heardPairs = new Set(pairsOf(heard)), pairs = pairsOf(words)
  return pairs.filter((p) => heardPairs.has(p)).length * 2 >= pairs.length
}

function release(pending, before) {
  const ready = pending.filter((p) => p.at < before).sort((a, b) => a.at - b.at)
  const rest = pending.filter((p) => p.at >= before)
  pending.length = 0
  pending.push(...rest)
  return ready
}

const heading = (label) => `**${label}:**`
const turnLine = (label, text) => `${heading(label)} ${text}`

function relabel(body, from, to) {
  if (!from || from === to || !body.includes(heading(from))) return body
  return body.replace(new RegExp('^' + escapeRegExp(heading(from)), 'gm'), () => heading(to))
}

function meetingHeader(now = new Date(), app = '') {
  const day = now.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
  const time = now.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
  return `# ${app ? `${app} meeting` : 'Meeting'}, ${day} at ${time}\n`
}

function trimSilence(samples, threshold = 500, lead = 1600, tail = 3200) {
  let start = 0, end = samples.length - 1
  for (let i = 0; i < samples.length; i++) if (Math.abs(samples[i]) > threshold) { start = Math.max(0, i - lead); break }
  for (let i = samples.length - 1; i >= 0; i--) if (Math.abs(samples[i]) > threshold) { end = Math.min(samples.length - 1, i + tail); break }
  return samples.subarray(start, end + 1)
}

const peak = (samples) => samples.reduce((m, s) => Math.max(m, Math.abs(s)), 0)

function wav(samples) {
  const data = Buffer.from(samples.buffer, samples.byteOffset, samples.byteLength)
  const header = Buffer.alloc(44)
  header.write('RIFF', 0); header.writeUInt32LE(36 + data.length, 4); header.write('WAVE', 8)
  header.write('fmt ', 12); header.writeUInt32LE(16, 16); header.writeUInt16LE(1, 20); header.writeUInt16LE(1, 22)
  header.writeUInt32LE(RATE, 24); header.writeUInt32LE(RATE * 2, 28); header.writeUInt16LE(2, 32); header.writeUInt16LE(16, 34)
  header.write('data', 36); header.writeUInt32LE(data.length, 40)
  return Buffer.concat([header, data])
}

module.exports = {
  RATE, isUsable, formatText, correct, applySnippets, expandPlaceholders, voiceCommand, VOICE_COMMANDS,
  biasPrompt, soundKey, derivedTitle, displayTitle, turns, isEcho, release, heading, turnLine, relabel,
  meetingHeader, trimSilence, peak, wav,
}
