const test = require('node:test')
const assert = require('node:assert/strict')
const t = require('./text')

const seg = (start, end, text) => ({ start, end, text })

test('turns split on silence measured from the last word', () => {
  assert.equal(t.turns([seg(0, 2.5, ' We should ship it.'), seg(2.5, 5, ' The tests are green.')]).length, 1)
  const split = t.turns([seg(0, 1, ' Right, that is agreed.'), seg(1, 9, '  '), seg(9, 10.5, ' Next item.')])
  assert.deepEqual(split.map((x) => x.text), ['Right, that is agreed.', 'Next item.'])
  assert.equal(split[1].start, 9)
  assert.equal(t.turns([seg(0, 1, ' One.'), seg(2.2, 3, ' Two.')]).length, 2)
  assert.equal(t.turns([seg(0, 1, ' One.'), seg(2.19, 3, ' Two.')]).length, 1)
})

test('echo is matched on word pairs', () => {
  const others = "Morning everyone. Let's start with the launch dates, Priya can you share your screen? Thanks."
  assert.ok(t.isEcho("Let's start with the launch date. Priya, can you share your screen.", others))
  assert.ok(t.isEcho('Thanks.', others))
  assert.ok(!t.isEcho('Sure, I can share the screen with everyone.', others))
  assert.ok(!t.isEcho('Yes.', others))
})

test('pending turns release in spoken order', () => {
  const pending = [{ at: 12, turn: 'b' }, { at: 3, turn: 'a' }, { at: 31, turn: 'c' }]
  assert.deepEqual(t.release(pending, 30).map((p) => p.turn), ['a', 'b'])
  assert.deepEqual(pending.map((p) => p.turn), ['c'])
})

test('relabel rewrites headings only, across line endings', () => {
  assert.equal(t.relabel('**You:** first\r\n\r\n**You:** said **You:** here\r\n', 'You', 'Sam'),
    '**Sam:** first\r\n\r\n**Sam:** said **You:** here\r\n')
  assert.equal(t.relabel('**C++ (Ana):** ok\n', 'C++ (Ana)', '$1'), '**$1:** ok\n')
})

test('non-speech captions are not usable', () => {
  for (const c of ['[BLANK_AUDIO]', '(music)', '[Music] (applause) [Music]', ' . ']) assert.ok(!t.isUsable(c), c)
  assert.ok(t.isUsable('We are back [laughs] for the last item.'))
})

test('formatText capitalises and handles spoken punctuation when asked', () => {
  assert.equal(t.formatText('i think so. and i\'m sure  of it'), "I think so. And I'm sure of it")
  assert.equal(t.formatText('First, buy milk. Second, call mum period', true), '1. Buy milk. \n2. Call mum.')
  assert.equal(t.formatText('see you at first light'), 'See you at first light')
})

test('dictionary keeps short words exact and fuzzes long ones', () => {
  assert.equal(t.correct('ask jon about kubernetes', ['Jon', 'Kubernetes']), 'ask Jon about Kubernetes')
  assert.equal(t.correct('the job is done', ['Jon']), 'the job is done')
  assert.equal(t.correct('Kubernets is up', ['Kubernetes']), 'Kubernetes is up')
  assert.equal(t.correct('KUBERNETS', ['Kubernetes']), 'KUBERNETES')
})

test('snippets expand every match with placeholders', () => {
  const now = new Date(2026, 4, 27, 15, 42)
  const out = t.applySnippets('My sign please. my sign', [{ trigger: 'my sign', expansion: 'Best, [day] $1' }], '', now)
  assert.equal(out, `Best, ${now.toLocaleDateString(undefined, { weekday: 'long' })} $1 please. Best, ${now.toLocaleDateString(undefined, { weekday: 'long' })} $1`)
})

test('voice commands match the end of the dictation', () => {
  assert.equal(t.voiceCommand('Okay, delete that.'), 'undo')
  assert.equal(t.voiceCommand('Start a new note!'), 'newNote')
  assert.equal(t.voiceCommand('the note is long'), null)
})

test('titles derive from the first real line', () => {
  assert.equal(t.derivedTitle('\r\n\r\n## Plan\r\nmore'), 'Plan')
  const long = 'word '.repeat(20)
  assert.ok(t.derivedTitle(long).endsWith('…') && t.derivedTitle(long).length <= 61)
  assert.equal(t.displayTitle({ title: '', body: '' }), 'Untitled note')
})

test('bias prompt stays under 420 characters', () => {
  assert.equal(t.biasPrompt(['ab', 'Okafor', 'okafor']), 'The following transcript may mention Okafor.')
  assert.ok(t.biasPrompt(Array.from({ length: 200 }, (_, i) => `Term${i}`)).length <= 420)
  assert.equal(t.biasPrompt([]), '')
})

test('trim keeps lead-in and tail and wav has a 44-byte header', () => {
  const s = new Int16Array(16000)
  s[8000] = 9000
  const trimmed = t.trimSilence(s)
  assert.equal(trimmed.length, 1600 + 1 + 3200)
  const w = t.wav(trimmed)
  assert.equal(w.length, 44 + trimmed.length * 2)
  assert.equal(w.toString('ascii', 0, 4), 'RIFF')
  assert.equal(t.meetingHeader(new Date(2026, 9, 14, 15, 42)), '# Meeting, Oct 14 at 3:42 PM\n')
  assert.equal(t.meetingHeader(new Date(2026, 9, 14, 15, 42), 'Zoom'), '# Zoom meeting, Oct 14 at 3:42 PM\n')
})

test('dictionary words heard as sound-alike spans are restored', () => {
  const words = ['Kubernetes', 'PostgreSQL', 'Grafana']
  assert.equal(t.correct('push the cooper netties config', words), 'push the Kubernetes config')
  assert.equal(t.correct('migrate the post grey sequel database', words), 'migrate the PostgreSQL database')
  assert.equal(t.correct('review the graph on a dashboard', words), 'review the Grafana dashboard')
  assert.equal(t.correct('we carve on the left', words), 'we carve on the left')
  assert.equal(t.correct('cooper, netties', words), 'cooper, netties')
  assert.equal(t.soundKey('Kubernetes'), t.soundKey('coopernetties'))
})
