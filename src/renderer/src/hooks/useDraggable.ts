import { useCallback, useRef, useEffect, useState } from 'react'

interface Position {
  x: number
  y: number
}

interface UseDraggableOptions {
  initialPosition: Position
  containerRef?: React.RefObject<HTMLElement | null>
  elementRef?: React.RefObject<HTMLElement | null>
  onDragStart?: () => void
  onDragEnd?: (position: Position) => void
}

export function useDraggable({
  initialPosition,
  containerRef,
  elementRef,
  onDragStart,
  onDragEnd
}: UseDraggableOptions) {
  const [position, setPosition] = useState<Position>(initialPosition)
  const [isDragging, setIsDragging] = useState(false)
  const dragStartPos = useRef<Position>({ x: 0, y: 0 })
  const elementStartPos = useRef<Position>({ x: 0, y: 0 })
  const positionRef = useRef<Position>(initialPosition)
  const pendingPosition = useRef<Position | null>(null)
  const frameRef = useRef<number | null>(null)
  const containerBounds = useRef<DOMRect | null>(null)

  useEffect(() => {
    setPosition(initialPosition)
    positionRef.current = initialPosition
  }, [initialPosition.x, initialPosition.y])

  const handlePointerDown = useCallback(
    (event: React.PointerEvent) => {
      // Only start drag on left mouse button
      if (event.button !== 0) return

      event.preventDefault()
      ;(event.target as HTMLElement).setPointerCapture(event.pointerId)
      setIsDragging(true)
      dragStartPos.current = { x: event.clientX, y: event.clientY }
      elementStartPos.current = { ...positionRef.current }
      containerBounds.current = containerRef?.current
        ? containerRef.current.getBoundingClientRect()
        : null
      onDragStart?.()

      if (elementRef?.current) {
        elementRef.current.style.willChange = 'transform'
      }
    },
    [elementRef, onDragStart]
  )

  useEffect(() => {
    if (!isDragging) return

    const handlePointerMove = (event: PointerEvent) => {
      const dx = event.clientX - dragStartPos.current.x
      const dy = event.clientY - dragStartPos.current.y

      let newX = elementStartPos.current.x + dx
      let newY = elementStartPos.current.y + dy

      // Constrain to container bounds
      if (containerBounds.current) {
        const minX = 0
        const minY = 0
        const maxX = containerBounds.current.width - 100 // Leave some visible area
        const maxY = containerBounds.current.height - 30 // Leave title bar visible

        newX = Math.max(minX, Math.min(maxX, newX))
        newY = Math.max(minY, Math.min(maxY, newY))
      }

      pendingPosition.current = { x: newX, y: newY }

      if (elementRef?.current) {
        if (frameRef.current !== null) {
          return
        }
        frameRef.current = window.requestAnimationFrame(() => {
          const next = pendingPosition.current
          if (next && elementRef.current) {
            const dx = next.x - elementStartPos.current.x
            const dy = next.y - elementStartPos.current.y
            elementRef.current.style.transform = `translate3d(${dx}px, ${dy}px, 0)`
          }
          frameRef.current = null
        })
      } else {
        setPosition({ x: newX, y: newY })
      }
    }

    const handlePointerUp = () => {
      setIsDragging(false)
      if (frameRef.current !== null) {
        window.cancelAnimationFrame(frameRef.current)
        frameRef.current = null
      }

      const finalPosition = pendingPosition.current ?? positionRef.current
      pendingPosition.current = null
      containerBounds.current = null
      positionRef.current = finalPosition

      if (elementRef?.current) {
        elementRef.current.style.transform = ''
        elementRef.current.style.willChange = ''
      }

      setPosition(finalPosition)
      onDragEnd?.(finalPosition)
    }

    document.addEventListener('pointermove', handlePointerMove)
    document.addEventListener('pointerup', handlePointerUp)

    return () => {
      document.removeEventListener('pointermove', handlePointerMove)
      document.removeEventListener('pointerup', handlePointerUp)
      if (frameRef.current !== null) {
        window.cancelAnimationFrame(frameRef.current)
        frameRef.current = null
      }
    }
  }, [isDragging, containerRef, elementRef, onDragEnd])

  return {
    position,
    isDragging,
    handlePointerDown,
    setPosition
  }
}
