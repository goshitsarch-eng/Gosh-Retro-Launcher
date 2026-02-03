import { useCallback, useRef, useEffect, useState } from 'react'

interface Size {
  width: number
  height: number
}

interface Position {
  x: number
  y: number
}

type ResizeDirection = 'n' | 's' | 'e' | 'w' | 'ne' | 'nw' | 'se' | 'sw'

interface UseResizableOptions {
  initialSize: Size
  initialPosition: Position
  minSize?: Size
  containerRef?: React.RefObject<HTMLElement | null>
  elementRef?: React.RefObject<HTMLElement | null>
  onResizeStart?: () => void
  onResizeEnd?: (size: Size, position: Position) => void
}

export function useResizable({
  initialSize,
  initialPosition,
  minSize = { width: 150, height: 100 },
  containerRef,
  elementRef,
  onResizeStart,
  onResizeEnd
}: UseResizableOptions) {
  const [size, setSize] = useState<Size>(initialSize)
  const [position, setPosition] = useState<Position>(initialPosition)
  const [isResizing, setIsResizing] = useState(false)
  const resizeDirection = useRef<ResizeDirection | null>(null)
  const startPos = useRef<Position>({ x: 0, y: 0 })
  const startSize = useRef<Size>({ width: 0, height: 0 })
  const startElementPos = useRef<Position>({ x: 0, y: 0 })
  const sizeRef = useRef<Size>(initialSize)
  const positionRef = useRef<Position>(initialPosition)
  const pendingSize = useRef<Size | null>(null)
  const pendingPosition = useRef<Position | null>(null)
  const frameRef = useRef<number | null>(null)

  useEffect(() => {
    setSize(initialSize)
    sizeRef.current = initialSize
  }, [initialSize.width, initialSize.height])

  useEffect(() => {
    setPosition(initialPosition)
    positionRef.current = initialPosition
  }, [initialPosition.x, initialPosition.y])

  const handleResizeMouseDown = useCallback(
    (event: React.MouseEvent, direction: ResizeDirection) => {
      if (event.button !== 0) return

      event.preventDefault()
      event.stopPropagation()
      setIsResizing(true)
      resizeDirection.current = direction
      startPos.current = { x: event.clientX, y: event.clientY }
      startSize.current = { ...sizeRef.current }
      startElementPos.current = { ...positionRef.current }
      onResizeStart?.()

      if (elementRef?.current) {
        elementRef.current.style.willChange = 'width, height, left, top'
      }
    },
    [elementRef, onResizeStart]
  )

  useEffect(() => {
    if (!isResizing || !resizeDirection.current) return

    const handleMouseMove = (event: MouseEvent) => {
      const dx = event.clientX - startPos.current.x
      const dy = event.clientY - startPos.current.y
      const dir = resizeDirection.current!

      let newWidth = startSize.current.width
      let newHeight = startSize.current.height
      let newX = startElementPos.current.x
      let newY = startElementPos.current.y

      // Handle horizontal resize
      if (dir.includes('e')) {
        newWidth = Math.max(minSize.width, startSize.current.width + dx)
      } else if (dir.includes('w')) {
        const potentialWidth = startSize.current.width - dx
        if (potentialWidth >= minSize.width) {
          newWidth = potentialWidth
          newX = startElementPos.current.x + dx
        }
      }

      // Handle vertical resize
      if (dir.includes('s')) {
        newHeight = Math.max(minSize.height, startSize.current.height + dy)
      } else if (dir.includes('n')) {
        const potentialHeight = startSize.current.height - dy
        if (potentialHeight >= minSize.height) {
          newHeight = potentialHeight
          newY = startElementPos.current.y + dy
        }
      }

      // Clamp to container bounds
      if (containerRef?.current) {
        const containerRect = containerRef.current.getBoundingClientRect()
        const maxWidth = containerRect.width - newX
        const maxHeight = containerRect.height - newY
        if (newWidth > maxWidth) newWidth = Math.max(minSize.width, maxWidth)
        if (newHeight > maxHeight) newHeight = Math.max(minSize.height, maxHeight)
      }

      pendingSize.current = { width: newWidth, height: newHeight }
      pendingPosition.current = { x: newX, y: newY }

      if (elementRef?.current) {
        if (frameRef.current !== null) {
          return
        }
        frameRef.current = window.requestAnimationFrame(() => {
          const nextSize = pendingSize.current
          const nextPos = pendingPosition.current
          if (nextSize && nextPos && elementRef.current) {
            elementRef.current.style.width = `${nextSize.width}px`
            elementRef.current.style.height = `${nextSize.height}px`
            elementRef.current.style.left = `${nextPos.x}px`
            elementRef.current.style.top = `${nextPos.y}px`
          }
          frameRef.current = null
        })
      } else {
        setSize({ width: newWidth, height: newHeight })
        setPosition({ x: newX, y: newY })
      }
    }

    const handleMouseUp = () => {
      setIsResizing(false)
      resizeDirection.current = null
      if (frameRef.current !== null) {
        window.cancelAnimationFrame(frameRef.current)
        frameRef.current = null
      }

      const finalSize = pendingSize.current ?? sizeRef.current
      const finalPosition = pendingPosition.current ?? positionRef.current
      pendingSize.current = null
      pendingPosition.current = null
      sizeRef.current = finalSize
      positionRef.current = finalPosition

      if (elementRef?.current) {
        elementRef.current.style.willChange = ''
      }

      setSize(finalSize)
      setPosition(finalPosition)
      onResizeEnd?.(finalSize, finalPosition)
    }

    document.addEventListener('mousemove', handleMouseMove)
    document.addEventListener('mouseup', handleMouseUp)

    return () => {
      document.removeEventListener('mousemove', handleMouseMove)
      document.removeEventListener('mouseup', handleMouseUp)
      if (frameRef.current !== null) {
        window.cancelAnimationFrame(frameRef.current)
        frameRef.current = null
      }
    }
  }, [isResizing, minSize, containerRef, elementRef, onResizeEnd])

  return {
    size,
    position,
    isResizing,
    handleResizeMouseDown,
    setSize,
    setPosition
  }
}
