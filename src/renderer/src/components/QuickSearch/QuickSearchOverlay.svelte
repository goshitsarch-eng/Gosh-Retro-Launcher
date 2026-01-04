<script lang="ts">
  import TextInput from '../Common/TextInput.svelte'
  import Icon from '../Common/Icon.svelte'
  import { uiStore, programStore } from '@/stores'
  import { getIconSrc } from '@/utils/icons'
  import type { ProgramItem, ProgramGroup } from '@shared/types'

  interface SearchResult {
    item: ProgramItem
    group: ProgramGroup
  }

  let query = $state('')
  let selectedIndex = $state(0)
  let inputRef: HTMLInputElement | undefined = $state()

  let groups = $derived(programStore.groups)
  let settings = $derived(programStore.settings)

  // Focus input on mount
  $effect(() => {
    inputRef?.focus()
  })

  // Filter results based on query
  let results = $derived.by<SearchResult[]>(() => {
    if (!query.trim()) return []

    const searchTerm = query.toLowerCase()
    const matches: SearchResult[] = []

    for (const group of groups) {
      for (const item of group.items) {
        if (item.name.toLowerCase().includes(searchTerm)) {
          matches.push({ item, group })
        }
      }
    }

    return matches.slice(0, 10) // Limit to 10 results
  })

  // Reset selection when results change
  $effect(() => {
    results.length // dependency
    selectedIndex = 0
  })

  // Handle keyboard navigation
  function handleKeyDown(event: KeyboardEvent) {
    switch (event.key) {
      case 'ArrowDown':
        event.preventDefault()
        selectedIndex = Math.min(selectedIndex + 1, results.length - 1)
        break
      case 'ArrowUp':
        event.preventDefault()
        selectedIndex = Math.max(selectedIndex - 1, 0)
        break
      case 'Enter':
        event.preventDefault()
        if (results[selectedIndex]) {
          launchItem(results[selectedIndex].item)
        }
        break
      case 'Escape':
        event.preventDefault()
        uiStore.closeQuickSearch()
        break
    }
  }

  // Launch selected item
  async function launchItem(item: ProgramItem) {
    const result = await window.electronAPI.program.launch(item)
    if (!result.success) {
      console.error('Failed to launch:', result.error)
    }

    uiStore.closeQuickSearch()

    if (settings.minimizeOnUse) {
      window.electronAPI.window.minimize()
    }
  }

  // Handle item click
  function handleItemClick(item: ProgramItem) {
    launchItem(item)
  }

  // Handle overlay click to close
  function handleOverlayClick(event: MouseEvent) {
    if (event.target === event.currentTarget) {
      uiStore.closeQuickSearch()
    }
  }
</script>

<div class="win31-dialog-overlay" onclick={handleOverlayClick} role="dialog" aria-modal="true">
  <div class="win31-dialog quick-search-dialog" style="width: 400px;">
    <div class="win31-titlebar">
      <span class="win31-titlebar-text">Quick Search</span>
    </div>
    <div class="win31-dialog-content">
      <TextInput
        bind:ref={inputRef}
        bind:value={query}
        onkeydown={handleKeyDown}
        placeholder="Type to search programs..."
        style="margin-bottom: 8px;"
      />

      {#if results.length > 0}
        <div
          class="quick-search-results"
          style="
            max-height: 300px;
            overflow-y: auto;
            border: 1px solid var(--bevel-dark);
            border-color: var(--bevel-dark) var(--bevel-light) var(--bevel-light) var(--bevel-dark);
            background: var(--win31-white);
          "
        >
          {#each results as result, index (`${result.group.id}-${result.item.id}`)}
            <div
              class="quick-search-item {index === selectedIndex ? 'selected' : ''}"
              onclick={() => handleItemClick(result.item)}
              onmouseenter={() => selectedIndex = index}
              role="option"
              aria-selected={index === selectedIndex}
              style="
                display: flex;
                align-items: center;
                gap: 8px;
                padding: 4px 8px;
                cursor: default;
                background-color: {index === selectedIndex ? 'var(--selection-bg)' : 'transparent'};
                color: {index === selectedIndex ? 'var(--selection-text)' : 'var(--text-primary)'};
              "
            >
              <Icon
                src={getIconSrc(result.item.icon)}
                size="small"
              />
              <div style="flex: 1;">
                <div style="font-weight: bold;">{result.item.name}</div>
                <div style="font-size: 10px; opacity: 0.8;">{result.group.name}</div>
              </div>
            </div>
          {/each}
        </div>
      {/if}

      {#if query && results.length === 0}
        <div style="padding: 16px; text-align: center; color: var(--text-disabled);">
          No results found
        </div>
      {/if}
    </div>
  </div>
</div>
