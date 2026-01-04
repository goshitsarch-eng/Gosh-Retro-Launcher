<script lang="ts">
  import type { Snippet } from 'svelte'

  interface Props {
    label: string
    hotkey?: string
    shortcut?: string
    disabled?: boolean
    checkbox?: boolean
    checked?: boolean
    hasSubmenu?: boolean
    submenu?: Snippet
    onClick?: () => void
  }

  let {
    label,
    hotkey,
    shortcut,
    disabled = false,
    checkbox = false,
    checked = false,
    hasSubmenu = false,
    submenu,
    onClick
  }: Props = $props()

  let showSubmenu = $state(false)

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

  function handleClick() {
    if (disabled) return
    if (hasSubmenu) return
    onClick?.()
  }

  function handleMouseEnter() {
    if (hasSubmenu) {
      showSubmenu = true
    }
  }

  function handleMouseLeave() {
    if (hasSubmenu) {
      showSubmenu = false
    }
  }

  let classNames = $derived(
    [
      'win31-menu-item',
      disabled && 'disabled',
      checkbox && 'checkbox',
      checkbox && checked && 'checked',
      hasSubmenu && 'has-submenu'
    ]
      .filter(Boolean)
      .join(' ')
  )
</script>

<div
  class={classNames}
  onclick={handleClick}
  onmouseenter={handleMouseEnter}
  onmouseleave={handleMouseLeave}
  role="menuitem"
>
  {labelParts.before}{#if labelParts.hotkey}<span class="hotkey">{labelParts.hotkey}</span>{/if}{labelParts.after}
  {#if shortcut}
    <span class="shortcut">{shortcut}</span>
  {/if}
  {#if hasSubmenu && showSubmenu && submenu}
    <div class="win31-submenu">
      {@render submenu()}
    </div>
  {/if}
</div>
