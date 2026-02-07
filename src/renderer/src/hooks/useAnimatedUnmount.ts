import { useState, useEffect, useCallback } from 'react'

interface UseAnimatedUnmountResult {
  shouldRender: boolean
  animClass: 'open' | 'closing' | ''
  onAnimationEnd: () => void
}

export function useAnimatedUnmount(
  isVisible: boolean,
  exitDuration: number
): UseAnimatedUnmountResult {
  const [shouldRender, setShouldRender] = useState(isVisible)
  const [animClass, setAnimClass] = useState<'open' | 'closing' | ''>(isVisible ? 'open' : '')

  useEffect(() => {
    if (isVisible) {
      setShouldRender(true)
      setAnimClass('open')
    } else if (shouldRender) {
      setAnimClass('closing')
      const timer = setTimeout(() => {
        setShouldRender(false)
        setAnimClass('')
      }, exitDuration)
      return () => clearTimeout(timer)
    }
  }, [isVisible, exitDuration])

  const onAnimationEnd = useCallback(() => {
    if (!isVisible) {
      setShouldRender(false)
      setAnimClass('')
    }
  }, [isVisible])

  return { shouldRender, animClass, onAnimationEnd }
}
