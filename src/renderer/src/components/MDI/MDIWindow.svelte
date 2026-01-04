<script lang="ts">
  import MDIWindowControls from './MDIWindowControls.svelte'
  import ItemGrid from '../Items/ItemGrid.svelte'
  import { createDraggable } from '@/lib/draggable.svelte'
  import { createResizable } from '@/lib/resizable.svelte'
  import { programStore, mdiStore, uiStore } from '@/stores'
  import type { ProgramGroup } from '@shared/types'

  interface Props {
    group: ProgramGroup
    isActive: boolean
    zIndex: number
    getContainerRef: () => HTMLDivElement | undefined
    onFocus: () => void
  }

  let { group, isActive, zIndex, getContainerRef, onFocus }: Props = $props()

  let windowRef: HTMLDivElement | undefined = $state()

  let windowState = $derived(group.windowState)

  // Handle drag end
  function handleDragEnd(position: { x: number; y: number }) {
    programStore.updateGroupWindowState(group.id, { x: position.x, y: position.y })
  }

  // Handle resize end
  function handleResizeEnd(size: { width: number; height: number }, position: { x: number; y: number }) {
    programStore.updateGroupWindowState(group.id, {
      width: size.width,
      height: size.height,
      x: position.x,
      y: position.y
    })
  }

  const draggable = createDraggable({
    get initialPosition() { return { x: windowState.x, y: windowState.y } },
    getContainerRef,
    getElementRef: () => windowRef,
    onDragStart: onFocus,
    onDragEnd: handleDragEnd
  })

  const resizable = createResizable({
    get initialSize() { return { width: windowState.width, height: windowState.height } },
    get initialPosition() { return { x: windowState.x, y: windowState.y } },
    minSize: { width: 150, height: 100 },
    getElementRef: () => windowRef,
    onResizeStart: onFocus,
    onResizeEnd: handleResizeEnd
  })

  // Window actions
  function handleMinimize() {
    programStore.updateGroupWindowState(group.id, { minimized: true })
    mdiStore.closeWindow(group.id)
  }

  function handleMaximize() {
    programStore.updateGroupWindowState(group.id, {
      maximized: !windowState.maximized
    })
  }

  function handleClose() {
    programStore.updateGroupWindowState(group.id, { minimized: true })
    mdiStore.closeWindow(group.id)
  }

  // Handle right-click on titlebar to open group properties
  function handleTitleBarContextMenu(event: MouseEvent) {
    event.preventDefault()
    uiStore.openDialog('groupProperties', { group })
  }

  // Use resizePosition if resizing, otherwise dragPosition
  let x = $derived(resizable.position.x || draggable.position.x)
  let y = $derived(resizable.position.y || draggable.position.y)
  let width = $derived(windowState.maximized ? '100%' : `${resizable.size.width}px`)
  let height = $derived(windowState.maximized ? '100%' : `${resizable.size.height}px`)
</script>

<div
  bind:this={windowRef}
  class="win31-mdi-window {isActive ? 'active' : 'inactive'} {windowState.maximized ? 'maximized' : ''}"
  style="left: {windowState.maximized ? 0 : x}px; top: {windowState.maximized ? 0 : y}px; width: {width}; height: {height}; z-index: {zIndex};"
  onmousedown={onFocus}
  role="dialog"
>
  <!-- Title bar -->
  <div
    class="win31-titlebar"
    onmousedown={windowState.maximized ? undefined : draggable.handleMouseDown}
    oncontextmenu={handleTitleBarContextMenu}
    role="heading"
  >
    <span class="win31-titlebar-text">{group.name}</span>
    <MDIWindowControls
      onMinimize={handleMinimize}
      onMaximize={handleMaximize}
      onClose={handleClose}
      isMaximized={windowState.maximized}
    />
  </div>

  <!-- Content area -->
  <div class="win31-window-body">
    <ItemGrid groupId={group.id} items={group.items} />
  </div>

  <!-- Resize handles (only when not maximized) -->
  {#if !windowState.maximized}
    <div
      class="resize-handle resize-handle-n"
      onmousedown={(e) => resizable.handleResizeMouseDown(e, 'n')}
      role="separator"
    ></div>
    <div
      class="resize-handle resize-handle-s"
      onmousedown={(e) => resizable.handleResizeMouseDown(e, 's')}
      role="separator"
    ></div>
    <div
      class="resize-handle resize-handle-w"
      onmousedown={(e) => resizable.handleResizeMouseDown(e, 'w')}
      role="separator"
    ></div>
    <div
      class="resize-handle resize-handle-e"
      onmousedown={(e) => resizable.handleResizeMouseDown(e, 'e')}
      role="separator"
    ></div>
    <div
      class="resize-handle resize-handle-nw"
      onmousedown={(e) => resizable.handleResizeMouseDown(e, 'nw')}
      role="separator"
    ></div>
    <div
      class="resize-handle resize-handle-ne"
      onmousedown={(e) => resizable.handleResizeMouseDown(e, 'ne')}
      role="separator"
    ></div>
    <div
      class="resize-handle resize-handle-sw"
      onmousedown={(e) => resizable.handleResizeMouseDown(e, 'sw')}
      role="separator"
    ></div>
    <div
      class="resize-handle resize-handle-se"
      onmousedown={(e) => resizable.handleResizeMouseDown(e, 'se')}
      role="separator"
    ></div>
  {/if}
</div>
