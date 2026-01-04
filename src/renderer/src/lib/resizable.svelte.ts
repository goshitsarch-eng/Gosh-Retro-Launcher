export interface Size {
  width: number
  height: number
}

export interface Position {
  x: number
  y: number
}

export type ResizeDirection = 'n' | 's' | 'e' | 'w' | 'ne' | 'nw' | 'se' | 'sw'

export interface ResizableOptions {
  initialSize: Size
  initialPosition: Position
  minSize?: Size
  getElementRef?: () => HTMLElement | undefined
  onResizeStart?: () => void
  onResizeEnd?: (size: Size, position: Position) => void
}

export function createResizable(options: ResizableOptions) {
  const minSize = options.minSize ?? { width: 150, height: 100 }

  let size = $state<Size>({ ...options.initialSize })
  let position = $state<Position>({ ...options.initialPosition })
  let isResizing = $state(false)

  // Internal refs (not reactive)
  let resizeDirection: ResizeDirection | null = null
  let startPos = { x: 0, y: 0 }
  let startSize = { width: 0, height: 0 }
  let startElementPos = { x: 0, y: 0 }
  let sizeRef = { ...options.initialSize }
  let positionRef = { ...options.initialPosition }
  let pendingSize: Size | null = null
  let pendingPosition: Position | null = null
  let frameRef: number | null = null

  // Sync with initial size changes
  $effect(() => {
    const newSize = options.initialSize
    size = { width: newSize.width, height: newSize.height }
    sizeRef = { width: newSize.width, height: newSize.height }
  })

  // Sync with initial position changes
  $effect(() => {
    const newPos = options.initialPosition
    position = { x: newPos.x, y: newPos.y }
    positionRef = { x: newPos.x, y: newPos.y }
  })

  function handleResizeMouseDown(event: MouseEvent, direction: ResizeDirection) {
    if (event.button !== 0) return

    event.preventDefault()
    event.stopPropagation()
    isResizing = true
    resizeDirection = direction
    startPos = { x: event.clientX, y: event.clientY }
    startSize = { ...sizeRef }
    startElementPos = { ...positionRef }
    options.onResizeStart?.()

    const element = options.getElementRef?.()
    if (element) {
      element.style.willChange = 'width, height, left, top'
    }

    // Add event listeners
    document.addEventListener('mousemove', handleMouseMove)
    document.addEventListener('mouseup', handleMouseUp)
  }

  function handleMouseMove(event: MouseEvent) {
    const dx = event.clientX - startPos.x
    const dy = event.clientY - startPos.y
    const dir = resizeDirection!

    let newWidth = startSize.width
    let newHeight = startSize.height
    let newX = startElementPos.x
    let newY = startElementPos.y

    // Handle horizontal resize
    if (dir.includes('e')) {
      newWidth = Math.max(minSize.width, startSize.width + dx)
    } else if (dir.includes('w')) {
      const potentialWidth = startSize.width - dx
      if (potentialWidth >= minSize.width) {
        newWidth = potentialWidth
        newX = startElementPos.x + dx
      }
    }

    // Handle vertical resize
    if (dir.includes('s')) {
      newHeight = Math.max(minSize.height, startSize.height + dy)
    } else if (dir.includes('n')) {
      const potentialHeight = startSize.height - dy
      if (potentialHeight >= minSize.height) {
        newHeight = potentialHeight
        newY = startElementPos.y + dy
      }
    }

    pendingSize = { width: newWidth, height: newHeight }
    pendingPosition = { x: newX, y: newY }

    const element = options.getElementRef?.()
    if (element) {
      if (frameRef !== null) {
        return
      }
      frameRef = window.requestAnimationFrame(() => {
        const nextSize = pendingSize
        const nextPos = pendingPosition
        if (nextSize && nextPos && element) {
          element.style.width = `${nextSize.width}px`
          element.style.height = `${nextSize.height}px`
          element.style.left = `${nextPos.x}px`
          element.style.top = `${nextPos.y}px`
        }
        frameRef = null
      })
    } else {
      size = { width: newWidth, height: newHeight }
      position = { x: newX, y: newY }
    }
  }

  function handleMouseUp() {
    isResizing = false
    resizeDirection = null

    if (frameRef !== null) {
      window.cancelAnimationFrame(frameRef)
      frameRef = null
    }

    const finalSize = pendingSize ?? sizeRef
    const finalPosition = pendingPosition ?? positionRef
    pendingSize = null
    pendingPosition = null
    sizeRef = finalSize
    positionRef = finalPosition

    const element = options.getElementRef?.()
    if (element) {
      element.style.willChange = ''
    }

    size = { ...finalSize }
    position = { ...finalPosition }
    options.onResizeEnd?.(finalSize, finalPosition)

    // Remove event listeners
    document.removeEventListener('mousemove', handleMouseMove)
    document.removeEventListener('mouseup', handleMouseUp)
  }

  function setSize(newSize: Size) {
    size = { ...newSize }
    sizeRef = { ...newSize }
  }

  function setPosition(newPosition: Position) {
    position = { ...newPosition }
    positionRef = { ...newPosition }
  }

  return {
    get size() { return size },
    get position() { return position },
    get isResizing() { return isResizing },
    handleResizeMouseDown,
    setSize,
    setPosition
  }
}
