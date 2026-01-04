<script lang="ts">
  import ProgramItem from './ProgramItem.svelte'
  import { uiStore, programStore } from '@/stores'
  import type { ProgramItem as ProgramItemType } from '@shared/types'

  interface Props {
    groupId: string
    items: ProgramItemType[]
  }

  let { groupId, items }: Props = $props()

  let isDragOver = $state(false)

  // Handle item selection
  function handleSelectItem(itemId: string) {
    uiStore.setSelectedItem(itemId, groupId)
  }

  // Handle click on empty area to deselect
  function handleBackgroundClick(event: MouseEvent) {
    if (event.target === event.currentTarget) {
      uiStore.clearSelection()
    }
  }

  // Handle drag over
  function handleDragOver(event: DragEvent) {
    event.preventDefault()
    if (event.dataTransfer) {
      event.dataTransfer.dropEffect = 'copy'
    }
    isDragOver = true
  }

  // Handle drag leave
  function handleDragLeave() {
    isDragOver = false
  }

  // Handle drop
  function handleDrop(event: DragEvent) {
    event.preventDefault()
    isDragOver = false

    const files = event.dataTransfer?.files
    if (!files || files.length === 0) return

    Array.from(files).forEach((file) => {
      // Get the file path (Tauri-specific)
      const filePath = (file as any).path as string
      if (!filePath) return

      // Extract filename without extension for display name
      const fileName = file.name
      const nameWithoutExt = fileName.replace(/\.[^/.]+$/, '')

      programStore.addItem(groupId, {
        name: nameWithoutExt,
        path: filePath,
        icon: 'default-item.png',
        workingDir: '',
        shortcutKey: '',
        launchGroup: 0
      })
    })
  }
</script>

<div
  class="win31-item-grid {isDragOver ? 'drag-over' : ''}"
  onclick={handleBackgroundClick}
  ondragover={handleDragOver}
  ondragleave={handleDragLeave}
  ondrop={handleDrop}
  role="grid"
>
  {#each items as item (item.id)}
    <ProgramItem
      {item}
      {groupId}
      isSelected={uiStore.selectedItemId === item.id && uiStore.selectedGroupId === groupId}
      onSelect={() => handleSelectItem(item.id)}
    />
  {/each}
  {#if items.length === 0}
    <div class="empty-message" style="color: #808080; padding: 20px;">
      Drag files here to add programs
    </div>
  {/if}
</div>
