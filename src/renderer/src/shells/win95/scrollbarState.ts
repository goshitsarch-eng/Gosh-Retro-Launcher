export interface Win95ThumbMetrics {
  trackLength: number
  thumbLength: number
  thumbOffset: number
  maxScroll: number
}

export function clampWin95Scroll(value: number, contentSize: number, viewportSize: number): number {
  return Math.max(0, Math.min(Math.max(0, contentSize - viewportSize), Math.round(value)))
}

export function win95ThumbMetrics(
  viewportSize: number,
  contentSize: number,
  trackLength: number,
  minimumThumb = 8
): Win95ThumbMetrics {
  const safeTrack = Math.max(0, trackLength)
  const maxScroll = Math.max(0, contentSize - viewportSize)
  if (maxScroll === 0 || contentSize <= 0) return { trackLength: safeTrack, thumbLength: safeTrack, thumbOffset: 0, maxScroll }
  const thumbLength = Math.max(minimumThumb, Math.min(safeTrack, Math.floor(safeTrack * viewportSize / contentSize)))
  return { trackLength: safeTrack, thumbLength, thumbOffset: 0, maxScroll }
}

export function win95ThumbOffset(value: number, metrics: Win95ThumbMetrics): number {
  if (!metrics.maxScroll || metrics.trackLength <= metrics.thumbLength) return 0
  return Math.round(clampWin95Scroll(value, metrics.maxScroll, 0) / metrics.maxScroll * (metrics.trackLength - metrics.thumbLength))
}

export function win95ScrollFromThumb(offset: number, metrics: Win95ThumbMetrics): number {
  const available = metrics.trackLength - metrics.thumbLength
  if (available <= 0 || metrics.maxScroll <= 0) return 0
  return Math.round(Math.max(0, Math.min(available, offset)) / available * metrics.maxScroll)
}

export function win95ScrollStep(value: number, direction: -1 | 1, lineSize: number, contentSize: number, viewportSize: number): number {
  return clampWin95Scroll(value + direction * lineSize, contentSize, viewportSize)
}

export function win95ScrollPage(value: number, direction: -1 | 1, contentSize: number, viewportSize: number): number {
  return clampWin95Scroll(value + direction * Math.max(1, viewportSize - 16), contentSize, viewportSize)
}
