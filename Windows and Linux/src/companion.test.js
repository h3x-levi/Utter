const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { _test: c } = require('./companion')

const now = new Date(2026, 9, 14, 15, 42)

test('memories keep the words and lift out the time', () => {
  const call = c.parseMemory('Remind me to call mum tomorrow at 5pm', now)
  assert.equal(call.text, 'call mum')
  assert.equal(call.remindAt.getTime(), new Date(2026, 9, 15, 17, 0).getTime())
  assert.deepEqual(c.parseMemory('Remember that the wifi password is on the fridge', now), { text: 'the wifi password is on the fridge', remindAt: null })
  assert.equal(c.parseMemory('water the plants in 20 minutes', now).remindAt.getTime(), now.getTime() + 20 * 60000)
  assert.throws(() => c.parseMemory('   ', now), /Write what you want/)
  assert.throws(() => c.parseMemory('x'.repeat(1001), now), /1,000/)
  assert.equal(c.stripCommandWords('please remember to buy milk.'), 'buy milk')
})

test('reminders come one at a time, pomodoro first', () => {
  const s = new c.ReminderScheduler()
  s.stretchEvery = 45 * 60000
  s.waterEvery = 20 * 60000
  s.pomodoroFocus = 25 * 60000
  s.pomodoroBreak = 5 * 60000
  s.begin(0)
  assert.equal(s.due(19 * 60000), null)
  assert.deepEqual(s.due(25 * 60000), { kind: 'pomodoro', focus: true })
  assert.deepEqual(s.due(25 * 60000), { kind: 'water' })
  assert.equal(s.pomodoroRemaining(27 * 60000), 3 * 60000)
  assert.deepEqual(s.due(30 * 60000), { kind: 'pomodoro', focus: false })
  assert.deepEqual(s.due(45 * 60000), { kind: 'stretch' })
  assert.equal(c.reminderLine({ kind: 'pomodoro', focus: true }, 'Sam'), 'Break time, Sam')
  assert.equal(c.reminderLine({ kind: 'water' }, ''), 'Water break')
  assert.equal(c.countdown(1499000), '24:59')
})

test('goals cheer exactly once and dismissals push the next reminder back', () => {
  const ud = { companionMemoryEnabled: true, companionGoalsEnabled: true, companionHydrationGoal: 2, companionStretchGoal: 3, companionFocusGoal: 2,
    companionDictationGoal: 500, companionProgress: { day: 20261013, hydration: 7, dictationWords: 900 } }
  assert.equal(c.recordReminder(ud, { kind: 'water' }, true, now), null)
  assert.equal(ud.companionProgress.hydration, 1, 'a new day starts the counts again')
  assert.equal(c.recordReminder(ud, { kind: 'water' }, true, now), 'Hydration goal complete')
  assert.equal(c.recordReminder(ud, { kind: 'water' }, true, now), null)
  c.recordReminder(ud, { kind: 'stretch' }, false, now)
  c.recordReminder(ud, { kind: 'stretch' }, false, now)
  assert.equal(ud.companionProgress.extraDelayMinutes.stretch, 10)
  assert.equal(ud.companionProgress.preferredHours.water, 15)
  const today = { ...ud, companionProgress: { ...ud.companionProgress, day: c.progressFor({}).day, dictationWords: 510 } }
  assert.ok(c.dictationGoalReached(today, 20))
  assert.ok(!c.dictationGoalReached(today, 5))
})

test('the robot shows a turn the way the Mac does', () => {
  const b = new c.Behaviour(() => {})
  b.apply('listening')
  assert.equal(b.robotState, 'input')
  const token = b.playToken
  b.apply('listening')
  assert.equal(b.playToken, token, 'a persistent state is not replayed')
  b.apply('thinking')
  b.apply('done')
  assert.equal(b.robotState, 'success')
  b.apply('listening')
  b.apply('notice')
  assert.equal(b.robotState, 'idle', 'a turn that never reached processing settles to idle')
  b.apply('error', { message: 'Couldn’t start the microphone' })
  assert.equal(b.robotState, 'failure')
  assert.deepEqual(b.notice, { kind: 'failure', line: 'Couldn’t start the microphone', detail: null })
  b.pinned = 'Ship the notes'
  b.quip = null
  b.setCountdown(1499000)
  assert.deepEqual(b.notice, { kind: 'timer', line: '24:59', detail: 'Ship the notes' })
  b.setQuiet(true)
  b.apply('listening')
  assert.equal(b.robotState, 'sleep')
})

test('memories round-trip in the Mac file shape and survive a damaged file', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'utter-memories-'))
  let created = 0
  const store = new c.MemoryStore(dir, { onCreated: () => created++, onCompleted() {}, onChange() {} })
  const later = new Date(Date.now() + 3600000)
  const m = store.add({ text: 'Call Sam', remindAt: later }, 'spoken')
  store.add({ text: 'Fridge', remindAt: null }, 'typed')
  assert.equal(created, 2)
  const saved = JSON.parse(fs.readFileSync(path.join(dir, 'companion-memories.json'), 'utf8'))
  assert.deepEqual(Object.keys(saved[1]), ['createdAt', 'id', 'remindAt', 'source', 'text'])
  assert.equal(saved[1].remindAt, later.getTime() / 1000)
  assert.equal(store.active[0].id, m.id, 'timed memories sort first')
  store.complete(m.id)
  assert.equal(store.completed.length, 1)
  fs.writeFileSync(path.join(dir, 'companion-memories.json'), '{broken')
  const reloaded = new c.MemoryStore(dir, { onCreated() {}, onCompleted() {}, onChange() {} })
  assert.equal(reloaded.memories.length, 2, 'the previous copy is restored')
  assert.ok(fs.readdirSync(dir).some((f) => f.startsWith('companion-memories-unreadable-')))
  fs.writeFileSync(path.join(dir, 'companion-memories.json'), JSON.stringify([{ id: 'A', text: 'old', createdAt: 1790000000000, source: 'typed' }]))
  assert.equal(new c.MemoryStore(dir, { onCreated() {}, onCompleted() {}, onChange() {} }).memories[0].createdAt, 1790000000, 'millisecond files still load')
})

test('the panel keeps the robot on screen and moves the bubble below when there is no room', () => {
  const g = c.geometry('medium')
  assert.equal(g.width, 220)
  assert.equal(g.height, Math.ceil(40 * 240 / 213 + 128))
  const work = { x: 0, y: 0, width: 1000, height: 800 }
  const origin = c.clampOrigin(g, { x: -500, y: -500 }, work)
  assert.ok(Math.abs(origin.x + g.robot.x) < 1, 'window positions are whole pixels')
  assert.equal(Math.round(origin.y + g.robot.y), 0)
  assert.ok(c.bubbleLayout(g, origin, work).below)
  assert.ok(c.bubbleLayout(g, origin, work).leading > 0)
  const ud = { companionSize: 'giant', companionStretchMinutes: 9000, companionHeadRoundness: 'round' }
  c.normalise(ud)
  assert.deepEqual([ud.companionSize, ud.companionStretchMinutes, ud.companionHeadRoundness, ud.companionWaterMinutes], ['medium', 480, 50, 0])
})

const listening = (onChange = () => {}) => {
  const b = new c.Behaviour(() => onChange(b))
  b.tag('listening', { mode: 'recording', destination: 'app' })
  b.apply('listening')
  return b
}

test('a cue carries the clock and arrives in the same update as its state', () => {
  const seen = []
  const b = listening((robot) => seen.push([robot.robotState, robot.cue?.event]))
  assert.deepEqual(seen, [['input', 'listening']])
  const { time, hour, weekday, month, day, ...rest } = b.cue.detail
  assert.deepEqual(rest, { mode: 'recording', destination: 'app' })
  assert.ok(time && [hour, weekday, month, day].every(Number.isInteger))
  const id = b.cue.id
  b.tag('thinking')
  assert.equal(b.cue.id, id + 1)
})

test('turn notes ride on the turn-end cue, then the turn clears', () => {
  const b = listening()
  b.note({ words: 40, total: 1010, destination: 'note' })
  b.note({ goal: 'dictation' })
  b.tag('island', { message: 'the dictated words' })
  const { words, total, destination, goal, message } = b.cue.detail
  assert.deepEqual([words, total, destination, goal, message], [40, 1010, 'note', 'dictation', undefined], 'no cue carries a message')
  b.tag('error', { message: 'No speech detected' })
  assert.equal(b.cue.detail.words, undefined)
  b.note({ remembered: true, timed: false })
  b.tag('listening', { mode: 'handsFree', destination: 'memory' })
  b.tag('notice')
  assert.equal(b.cue.detail.remembered, undefined, 'listening starts a new turn')
})

test('hearing cues talking after four loud seconds, once a turn', () => {
  const b = listening()
  const heard = []
  for (let t = 0; t <= 6000; t += 50) heard.push(b.hear(0.3, t))
  assert.deepEqual(heard.filter(Boolean), ['talking'])
  assert.equal(heard.indexOf('talking') * 50, c.HEAR.talkingMs)
  const gaps = listening()
  for (let t = 0; t < 30 * 1000; t += 1000) assert.equal(gaps.hear(0.3, t), null, 'a gap counts as 100 ms at most')
  assert.equal(gaps.hearing.loudMs, 2900)
})

test('hearing cues quiet after two soft seconds; silence or a loud sample starts it again', () => {
  const b = listening()
  const at = (pairs) => pairs.map(([t, level]) => b.hear(level, t))
  assert.deepEqual(at([[0, 0.05], [1900, 0.05], [1950, 0], [2000, 0.05], [3999, 0.05], [4000, 0.3], [4100, 0.05]]).filter(Boolean), [])
  assert.equal(b.hear(0.05, 6100), 'quiet')
  assert.equal(b.cue.event, 'quiet')
  assert.equal(b.hear(0.05, 9000), null)
})

test('hearing only listens in input and starts over with each listening', () => {
  const b = new c.Behaviour(() => {})
  assert.equal(b.hear(0.3, 0), null)
  let sent = 0
  const l = listening(() => sent++)
  for (let t = 0; t <= 4000; t += 100) l.hear(0.3, t)
  assert.equal(l.cue.event, 'talking')
  assert.equal(sent, 2, 'a heard cue is sent at once')
  l.tag('listening', { mode: 'handsFree', destination: 'app' })
  for (let t = 5000; t <= 9000; t += 100) l.hear(0.3, t)
  assert.equal(l.cue.event, 'talking')
})

test('reminders and goals cue with their kind; the dictation goal is a turn note', (t) => {
  t.mock.timers.enable({ apis: ['setTimeout'] })
  const b = new c.Behaviour(() => {})
  b.announce({ kind: 'pomodoro', focus: true }, '')
  assert.deepEqual([b.cue.event, b.cue.detail.kind, b.cue.detail.focus, b.robotState], ['reminder', 'pomodoro', true, 'send'])
  b.announce({ kind: 'water' }, '')
  assert.equal(b.cue.detail.focus, false)
  b.celebrate('Hydration goal complete', 'hydration')
  assert.deepEqual([b.cue.event, b.cue.detail.kind, b.robotState], ['goal', 'hydration', 'love'])
  const id = b.cue.id
  b.celebrate('Dictation goal complete', 'dictation')
  assert.equal(b.cue.id, id, 'no cue of its own')
  b.tag('done')
  assert.equal(b.cue.detail.goal, 'dictation')
  b.setQuiet(true)
  b.announce({ kind: 'stretch' }, '')
  assert.equal(b.cue.event, 'done', 'quiet holds reminders back')
})

test('main and the player agree on the clock', async () => {
  const lib = require('./companion-moments.json')
  const player = await import('./companion-player.js')
  for (let hour = 0; hour < 24; hour++) {
    const date = new Date(2026, 0, 4, hour, 30)
    assert.deepEqual(c.clock(date), player.clock(lib, date), `${hour}:30`)
  }
  assert.deepEqual(c.clock(new Date(2026, 9, 31, 23, 30)), { time: 'night', hour: 23, weekday: 6, month: 10, day: 31 })
})

test('finish and accessory are strings that default to ink and nothing', () => {
  const ud = { companionFinish: 3, companionAccessory: null }
  c.normalise(ud)
  assert.deepEqual([ud.companionFinish, ud.companionAccessory], ['ink', ''])
  const kept = { companionFinish: 'retired-finish', companionAccessory: 'bow' }
  c.normalise(kept)
  assert.deepEqual([kept.companionFinish, kept.companionAccessory], ['retired-finish', 'bow'], 'unknown ids are judged when drawn, not stored')
})
