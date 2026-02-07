import { useMemo } from 'react'
import { useProgramStore } from '@/store/programStore'
import { createSoundPlayer, type SoundPlayer } from '@/utils/sounds'

export function useSounds(): SoundPlayer {
  return useMemo(
    () =>
      createSoundPlayer(() => {
        const settings = useProgramStore.getState().settings
        return settings.soundEnabled ?? true
      }),
    []
  )
}
