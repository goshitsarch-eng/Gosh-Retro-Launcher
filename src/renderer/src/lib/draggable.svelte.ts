export interface Position {
  x: number
  y: number
}

export interface DraggableOptions {
  initialPosition: Position
  getContainerRef?: () => HTMLElement | undefined
  getElementRef?: () => HTMLElement | undefined
  onDragStart?: () => void
  onDragEnd?: (position: Position) => void
}

export function createDraggable(options: DraggableOptions) {
  let position = $state<Position>({ ...options.initialPosition })
  let isDragging = $state(false)

  // Internal refs (not reactive)
  let dragStartPos = { x: 0, y: 0 }
  let elementStartPos = { x: 0, y: 0 }
  let positionRef = { ...options.initialPosition }
  let pendingPosition: Position | null = null
  let frameRef: number | null = null
  let containerBounds: DOMRect | null = null

  // Sync with initial position changes
  $effect(() => {
    const newPos = options.initialPosition
    position = { x: newPos.x, y: newPos.y }
    positionRef = { x: newPos.x, y: newPos.y }
  })

  function handleMouseDown(event: MouseEvent) {
    // Only start drag on left mouse button
    if (event.button !== 0) return

    event.preventDefault()
    isDragging = true
    dragStartPos = { x: event.clientX, y: event.clientY }
    elementStartPos = { ...positionRef }

    const container = options.getContainerRef?.()
    containerBounds = container ? container.getBoundingClientRect() : null

    options.onDragStart?.()

    const element = options.getElementRef?.()
    if (element) {
      element.style.willChange = 'transform'
    }

    // Add event listeners
    document.addEventListener('mousemove', handleMouseMove)
    document.addEventListener('mouseup', handleMouseUp)
  }

  function handleMouseMove(event: MouseEvent) {
    const dx = event.clientX - dragStartPos.x
    const dy = event.clientY - dragStartPos.y

    let newX = elementStartPos.x + dx
    let newY = elementStartPos.y + dy

    // Constrain to container bounds
    if (containerBounds) {
      const minX = 0
      const minY = 0
      const maxX = containerBounds.width - 100 // Leave some visible area
      const maxY = containerBounds.height - 30 // Leave title bar visible

      newX = Math.max(minX, Math.min(maxX, newX))
      newY = Math.max(minY, Math.min(maxY, newY))
    }

    pendingPosition = { x: newX, y: newY }

    const element = options.getElementRef?.()
    if (element) {
      if (frameRef !== null) {
        return
      }
      frameRef = window.requestAnimationFrame(() => {
        const next = pendingPosition
        if (next && element) {
          const dxTransform = next.x - elementStartPos.x
          const dyTransform = next.y - elementStartPos.y
          element.style.transform = `translate3d(${dxTransform}px, ${dyTransform}px, 0)`
        }
        frameRef = null
      })
    } else {
      position = { x: newX, y: newY }
    }
  }

  function handleMouseUp() {
    isDragging = false

    if (frameRef !== null) {
      window.cancelAnimationFrame(frameRef)
      frameRef = null
    }

    const finalPosition = pendingPosition ?? positionRef
    pendingPosition = null
    containerBounds = null
    positionRef = finalPosition

    const element = options.getElementRef?.()
    if (element) {
      element.style.transform = ''
      element.style.willChange = ''
    }

    position = { ...finalPosition }
    options.onDragEnd?.(finalPosition)

    // Remove event listeners
    document.removeEventListener('mousemove', handleMouseMove)
    document.removeEventListener('mouseup', handleMouseUp)
  }

  function setPosition(newPosition: Position) {
    position = { ...newPosition }
    positionRef = { ...newPosition }
  }

  return {
    get position() { return position },
    get isDragging() { return isDragging },
    handleMouseDown,
    setPosition
  }
}
