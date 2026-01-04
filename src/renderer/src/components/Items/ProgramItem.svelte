<script lang="ts">
  import Icon from '../Common/Icon.svelte'
  import { uiStore } from '@/stores'
  import { programStore } from '@/stores'
  import { getIconSrc } from '@/utils/icons'
  import type { ProgramItem as ProgramItemType } from '@shared/types'

  interface Props {
    item: ProgramItemType
    groupId: string
    isSelected: boolean
    onSelect: () => void
  }

  let { item, groupId, isSelected, onSelect }: Props = $props()

  // Get icon path using helper that provides embedded fallbacks
  let iconSrc = $derived(getIconSrc(item.icon))

  // Handle double-click to launch
  async function handleDoubleClick() {
    const result = await window.electronAPI.program.launch(item)
    if (!result.success) {
      console.error('Failed to launch program:', result.error)
    }

    // Minimize main window if setting is enabled
    if (programStore.settings.minimizeOnUse) {
      window.electronAPI.window.minimize()
    }
  }

  // Handle right-click context menu (properties)
  function handleContextMenu(event: MouseEvent) {
    event.preventDefault()
    onSelect()
    uiStore.openDialog('itemProperties', { groupId, item })
  }
</script>

<div
  class="win31-program-item {isSelected ? 'selected' : ''}"
  onclick={onSelect}
  ondblclick={handleDoubleClick}
  oncontextmenu={handleContextMenu}
  role="button"
  tabindex="0"
>
  <Icon src={iconSrc} alt={item.name} />
  <span class="label">{item.name}</span>
</div>
