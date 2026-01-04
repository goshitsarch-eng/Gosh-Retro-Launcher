<script lang="ts">
  import type { Snippet } from 'svelte'
  import { uiStore } from '@/stores'

  interface Props {
    label: string
    hotkey?: string
    isOpen: boolean
    onClick: () => void
    onHover: () => void
    children: Snippet
  }

  let { label, hotkey, isOpen, onClick, onHover, children }: Props = $props()

  let menuRef: HTMLDivElement | undefined = $state()

  // Parse label with hotkey underlined
  let labelParts = $derived.by(() => {
    if (!hotkey) return { before: label, hotkey: '', after: '' }

    const index = label.toLowerCase().indexOf(hotkey.toLowerCase())
    if (index === -1) return { before: label, hotkey: '', after: '' }

    return {
      before: label.slice(0, index),
      hotkey: label[index],
      after: label.slice(index + 1)
    }
  })

  // Close menu when clicking outside
  $effect(() => {
    if (!isOpen) return

    function handleClickOutside(event: MouseEvent) {
      if (menuRef && !menuRef.contains(event.target as Node)) {
        uiStore.setActiveMenu(null)
      }
    }

    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  })
</script>

<div
  bind:this={menuRef}
  class="win31-menu {isOpen ? 'open' : ''}"
>
  <button
    class="win31-menu-trigger"
    onclick={onClick}
    onmouseenter={onHover}
  >
    {labelParts.before}{#if labelParts.hotkey}<span class="hotkey">{labelParts.hotkey}</span>{/if}{labelParts.after}
  </button>
  {#if isOpen}
    <div class="win31-dropdown">
      {@render children()}
    </div>
  {/if}
</div>
