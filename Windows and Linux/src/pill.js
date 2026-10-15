const pill = document.getElementById('pill')
const label = pill.querySelector('.label')
const caption = document.getElementById('caption')
const island = document.getElementById('island')
const bars = [...pill.querySelectorAll('.bars i')]
const SHAPE = [0.45, 0.7, 0.9, 1, 0.9, 0.7, 0.45]
let state = 'rest'
let level = 0

utter.onPill(({ state: next, message = '', caption: words = '', island: held = '' }) => {
  state = next
  pill.className = next
  label.textContent = message
  pill.setAttribute('aria-label', message || next)
  caption.textContent = words
  caption.hidden = !words
  island.classList.toggle('open', next === 'island')
  island.querySelector('.words').textContent = held
})

island.addEventListener('click', (e) => {
  const action = e.target.closest('button')?.dataset.action
  if (action) utter.pillMouse(action)
})
let pressTimer = null
pill.addEventListener('pointerdown', () => { pressTimer = setTimeout(() => utter.pillMouse('long-press'), 2000) })
for (const end of ['pointerup', 'pointerleave']) pill.addEventListener(end, () => clearTimeout(pressTimer))

function draw(time) {
  bars.forEach((bar, i) => {
    let h = 3
    if (state === 'thinking') h = 3 + 7 * (0.5 + 0.5 * Math.sin(time / 140 - i * 0.9))
    else if (state === 'hover') h = 2 + 6 * SHAPE[i]
    else if (['listening', 'handsFree', 'note', 'memory'].includes(state)) h = 3 + 11 * level * SHAPE[i] * (0.8 + 0.2 * Math.sin(time / 90 + i * 2.1))
    bar.style.height = `${h.toFixed(1)}px`
  })
  requestAnimationFrame(draw)
}
requestAnimationFrame(draw)

function meter(samples) {
  let sum = 0
  for (const s of samples) sum += s * s
  const db = 20 * Math.log10(Math.sqrt(sum / samples.length) / 32768 + 1e-9)
  const target = Math.min(1, Math.max(0, (db + 50) / 45))
  level += (target - level) * (target > level ? 0.55 : 0.12)
}

pill.addEventListener('mouseenter', () => utter.pillMouse('enter'))
island.addEventListener('mouseenter', () => utter.pillMouse('enter'))
pill.addEventListener('mouseleave', () => utter.pillMouse('leave'))
pill.addEventListener('click', () => utter.pillMouse('click'))
pill.addEventListener('contextmenu', (e) => { e.preventDefault(); utter.pillMouse('menu') })

const sounds = Object.fromEntries(['start', 'stop', 'done', 'error'].map((name) => {
  const audio = new Audio(`../assets/sounds/${name}.wav`)
  audio.volume = 0.45
  return [name, audio]
}))

// Each stream opens and closes in order, so a quick double tap can't interleave them.
const open = {}
const queue = {}
const serial = (stream, job) => (queue[stream] = (queue[stream] || Promise.resolve()).then(job, job))

async function start(stream, media) {
  const ctx = new AudioContext({ sampleRate: 16000 })
  await ctx.audioWorklet.addModule('capture-worklet.js')
  const node = new AudioWorkletNode(ctx, 'capture', { numberOfOutputs: 0 })
  const entry = { ctx, media, node }
  node.port.onmessage = ({ data }) => {
    if (data === 'flushed') return entry.flushed?.()
    utter.sendPCM(stream, data)
    if (stream === 'mic') meter(new Int16Array(data))
  }
  ctx.createMediaStreamSource(media).connect(node)
  open[stream] = entry
  utter.captureEvent({ type: 'started', stream })
}

async function stop(stream) {
  const entry = open[stream]
  delete open[stream]
  if (entry) {
    await new Promise((resolve) => {
      entry.flushed = resolve
      entry.node.port.postMessage('flush')
      setTimeout(resolve, 600)
    })
    entry.media.getTracks().forEach((t) => t.stop())
    await entry.ctx.close()
  }
  level = 0
  utter.captureEvent({ type: 'stopped', stream })
}

async function microphone(deviceId) {
  const audio = { echoCancellation: false, noiseSuppression: false, autoGainControl: false, channelCount: 1 }
  if (!deviceId) return navigator.mediaDevices.getUserMedia({ audio })
  try {
    return await navigator.mediaDevices.getUserMedia({ audio: { ...audio, deviceId: { exact: deviceId } } })
  } catch {
    return navigator.mediaDevices.getUserMedia({ audio })
  }
}

const fail = (stream) => (error) => utter.captureEvent({ type: 'error', stream, message: String(error?.message || error) })

utter.onCapture(({ cmd, stream, deviceId, name }) => {
  if (cmd === 'sound') return sounds[name] && (sounds[name].currentTime = 0, sounds[name].play().catch(() => {}))
  if (cmd === 'open') serial(stream, () => microphone(deviceId).then((m) => start(stream, m)).catch(fail(stream)))
  if (cmd === 'close') serial(stream, () => stop(stream))
})

// Windows system audio. Main calls this with a user gesture, which getDisplayMedia needs.
window.startSystemAudio = () => serial('system', async () => {
  try {
    const media = await navigator.mediaDevices.getDisplayMedia({ video: true, audio: true })
    media.getVideoTracks().forEach((t) => t.stop())
    if (!media.getAudioTracks().length) throw new Error('No system audio track')
    await start('system', media)
  } catch (error) {
    fail('system')(error)
  }
})
