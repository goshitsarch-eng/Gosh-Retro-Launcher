import { afterEach, describe, expect, it, vi } from 'vitest'

class MockAudioParam {
  setValueAtTime = vi.fn()
  linearRampToValueAtTime = vi.fn()
  exponentialRampToValueAtTime = vi.fn()
}

class MockGainNode {
  gain = new MockAudioParam()
  connect = vi.fn()
  disconnect = vi.fn()
}

class MockOscillatorNode {
  type: OscillatorType = 'sine'
  frequency = new MockAudioParam()
  connect = vi.fn()
  disconnect = vi.fn()
  start = vi.fn()
  stop = vi.fn()
  private ended: (() => void) | null = null

  addEventListener(_type: string, listener: EventListenerOrEventListenerObject): void {
    this.ended = typeof listener === 'function' ? () => listener(new Event('ended')) : () => listener.handleEvent(new Event('ended'))
  }

  finish(): void {
    this.ended?.()
  }
}

class MockAudioContext {
  state: AudioContextState = 'running'
  currentTime = 0
  destination = {}
  oscillators: MockOscillatorNode[] = []
  gains: MockGainNode[] = []
  resume = vi.fn(async () => { this.state = 'running' })
  suspend = vi.fn(async () => { this.state = 'suspended' })

  createOscillator(): OscillatorNode {
    const node = new MockOscillatorNode()
    this.oscillators.push(node)
    return node as unknown as OscillatorNode
  }

  createGain(): GainNode {
    const node = new MockGainNode()
    this.gains.push(node)
    return node as unknown as GainNode
  }
}

describe('sound resource lifecycle', () => {
  afterEach(() => {
    vi.useRealTimers()
    vi.unstubAllGlobals()
    vi.resetModules()
  })

  it('disconnects ended nodes and suspends after the final overlapping tone', async () => {
    vi.useFakeTimers()
    const contexts: MockAudioContext[] = []
    vi.stubGlobal('AudioContext', class extends MockAudioContext {
      constructor() {
        super()
        contexts.push(this)
      }
    })
    const { playStartupChime } = await import('../sounds')

    playStartupChime()
    const context = contexts[0]
    expect(context.oscillators).toHaveLength(4)
    expect(context.gains).toHaveLength(4)

    context.oscillators.forEach((oscillator) => oscillator.finish())
    context.currentTime = 0.61
    await vi.advanceTimersByTimeAsync(749)
    expect(context.suspend).not.toHaveBeenCalled()
    await vi.advanceTimersByTimeAsync(2)

    expect(context.oscillators.every((node) => node.disconnect.mock.calls.length === 1)).toBe(true)
    expect(context.gains.every((node) => node.disconnect.mock.calls.length === 1)).toBe(true)
    expect(context.suspend).toHaveBeenCalledTimes(1)
  })

  it('resumes the lazy context when a later sound is requested', async () => {
    vi.useFakeTimers()
    const context = new MockAudioContext()
    vi.stubGlobal('AudioContext', class { constructor() { return context } })
    const { playMenuClick } = await import('../sounds')

    playMenuClick()
    context.oscillators[0].finish()
    context.currentTime = 0.04
    await vi.advanceTimersByTimeAsync(200)
    expect(context.state).toBe('suspended')

    playMenuClick()
    expect(context.resume).toHaveBeenCalledTimes(1)
  })
})
