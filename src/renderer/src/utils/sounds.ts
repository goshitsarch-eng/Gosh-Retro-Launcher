let audioCtx: AudioContext | null = null
let suspendTimer: ReturnType<typeof setTimeout> | null = null
let connectedToneCount = 0
let latestToneEndTime = 0

const SUSPEND_GRACE_MS = 150

function getContext(): AudioContext {
  if (!audioCtx || audioCtx.state === 'closed') {
    audioCtx = new AudioContext()
  }
  if (audioCtx.state === 'suspended') {
    void audioCtx.resume().catch(() => undefined)
  }
  return audioCtx
}

function cancelPendingSuspend(): void {
  if (suspendTimer !== null) {
    clearTimeout(suspendTimer)
    suspendTimer = null
  }
}

function scheduleSuspend(ctx: AudioContext, endTime: number): void {
  latestToneEndTime = Math.max(latestToneEndTime, endTime)
  cancelPendingSuspend()
  const delay = Math.max(0, (latestToneEndTime - ctx.currentTime) * 1000) + SUSPEND_GRACE_MS
  suspendTimer = setTimeout(() => {
    suspendTimer = null
    if (audioCtx !== ctx || ctx.state !== 'running' || connectedToneCount > 0) return
    latestToneEndTime = 0
    void ctx.suspend().catch(() => undefined)
  }, delay)
}

function connectTone(
  ctx: AudioContext,
  osc: OscillatorNode,
  gain: GainNode,
  startTime: number,
  endTime: number
): void {
  cancelPendingSuspend()
  connectedToneCount += 1
  let disconnected = false
  const disconnect = (): void => {
    if (disconnected) return
    disconnected = true
    osc.disconnect()
    gain.disconnect()
    connectedToneCount = Math.max(0, connectedToneCount - 1)
    scheduleSuspend(ctx, endTime)
  }

  osc.addEventListener('ended', disconnect, { once: true })
  osc.connect(gain)
  gain.connect(ctx.destination)
  osc.start(startTime)
  osc.stop(endTime)
  scheduleSuspend(ctx, endTime)
}

/** Suspend and release any pending audio work when the renderer is torn down. */
export function suspendSoundContext(): void {
  cancelPendingSuspend()
  latestToneEndTime = 0
  if (audioCtx?.state === 'running') {
    void audioCtx.suspend().catch(() => undefined)
  }
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

  const startTime = ctx.currentTime
  connectTone(ctx, osc, gain, startTime, startTime + duration)
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

    const startTime = now + tone.delay
    connectTone(ctx, osc, gain, startTime, startTime + tone.duration)
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
