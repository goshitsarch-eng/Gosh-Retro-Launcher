let audioCtx: AudioContext | null = null

function getContext(): AudioContext {
  if (!audioCtx) {
    audioCtx = new AudioContext()
  }
  if (audioCtx.state === 'suspended') {
    audioCtx.resume()
  }
  return audioCtx
}

interface ToneParams {
  freq: number
  duration: number
  type?: OscillatorType
  volume?: number
  rampTo?: number
}

function playTone({ freq, duration, type = 'square', volume = 0.08, rampTo }: ToneParams): void {
  const ctx = getContext()
  const osc = ctx.createOscillator()
  const gain = ctx.createGain()

  osc.type = type
  osc.frequency.setValueAtTime(freq, ctx.currentTime)
  if (rampTo !== undefined) {
    osc.frequency.linearRampToValueAtTime(rampTo, ctx.currentTime + duration)
  }

  gain.gain.setValueAtTime(volume, ctx.currentTime)
  gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + duration)

  osc.connect(gain)
  gain.connect(ctx.destination)
  osc.start(ctx.currentTime)
  osc.stop(ctx.currentTime + duration)
}

interface SequencedTone {
  freq: number
  duration: number
  delay: number
  type?: OscillatorType
  volume?: number
}

function playMultipleTones(tones: SequencedTone[]): void {
  const ctx = getContext()
  const now = ctx.currentTime

  for (const tone of tones) {
    const osc = ctx.createOscillator()
    const gain = ctx.createGain()

    osc.type = tone.type ?? 'square'
    osc.frequency.setValueAtTime(tone.freq, now + tone.delay)

    gain.gain.setValueAtTime(tone.volume ?? 0.06, now + tone.delay)
    gain.gain.exponentialRampToValueAtTime(0.001, now + tone.delay + tone.duration)

    osc.connect(gain)
    gain.connect(ctx.destination)
    osc.start(now + tone.delay)
    osc.stop(now + tone.delay + tone.duration)
  }
}

export function playStartupChime(): void {
  // C5 - E5 - G5 - C6 arpeggio
  playMultipleTones([
    { freq: 523, duration: 0.15, delay: 0 },
    { freq: 659, duration: 0.15, delay: 0.1 },
    { freq: 784, duration: 0.15, delay: 0.2 },
    { freq: 1047, duration: 0.3, delay: 0.3, volume: 0.08 }
  ])
}

export function playWindowOpen(): void {
  playTone({ freq: 300, duration: 0.1, rampTo: 500, volume: 0.06 })
}

export function playWindowClose(): void {
  playTone({ freq: 500, duration: 0.1, rampTo: 300, volume: 0.06 })
}

export function playMenuClick(): void {
  playTone({ freq: 800, duration: 0.03, volume: 0.05 })
}

export function playDialogOpen(): void {
  playMultipleTones([
    { freq: 600, duration: 0.08, delay: 0 },
    { freq: 800, duration: 0.1, delay: 0.06 }
  ])
}

export function playErrorBeep(): void {
  playMultipleTones([
    { freq: 200, duration: 0.1, delay: 0 },
    { freq: 200, duration: 0.1, delay: 0.15 }
  ])
}

export function playButtonClick(): void {
  playTone({ freq: 1000, duration: 0.02, volume: 0.04 })
}

export interface SoundPlayer {
  startupChime: () => void
  windowOpen: () => void
  windowClose: () => void
  menuClick: () => void
  dialogOpen: () => void
  errorBeep: () => void
  buttonClick: () => void
}

export function createSoundPlayer(getSoundEnabled: () => boolean): SoundPlayer {
  const wrap =
    (fn: () => void) =>
    (): void => {
      if (getSoundEnabled()) fn()
    }

  return {
    startupChime: wrap(playStartupChime),
    windowOpen: wrap(playWindowOpen),
    windowClose: wrap(playWindowClose),
    menuClick: wrap(playMenuClick),
    dialogOpen: wrap(playDialogOpen),
    errorBeep: wrap(playErrorBeep),
    buttonClick: wrap(playButtonClick)
  }
}
