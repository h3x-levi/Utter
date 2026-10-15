// Runs on the audio thread: 16 kHz float frames in, 100 ms Int16 chunks out.
class Capture extends AudioWorkletProcessor {
  constructor() {
    super()
    this.reset()
    this.port.onmessage = () => {
      if (this.n) this.port.postMessage(this.buf.slice(0, this.n).buffer)
      this.port.postMessage('flushed')
      this.reset()
    }
  }

  reset() {
    this.buf = new Int16Array(1600)
    this.n = 0
  }

  process([input]) {
    const channel = input[0]
    if (!channel) return true
    for (let i = 0; i < channel.length; i++) {
      const s = Math.max(-1, Math.min(1, channel[i]))
      this.buf[this.n++] = s < 0 ? s * 0x8000 : s * 0x7fff
      if (this.n === this.buf.length) {
        this.port.postMessage(this.buf.buffer, [this.buf.buffer])
        this.reset()
      }
    }
    return true
  }
}

registerProcessor('capture', Capture)
