<script lang="ts">
  import Dialog from './Dialog.svelte'
  import Button from '../Common/Button.svelte'
  import TextInput from '../Common/TextInput.svelte'
  import { uiStore, programStore } from '@/stores'
  import { LAUNCH_GROUP_OPTIONS, formatLaunchGroup } from '@/utils/launchGroups'

  function normalizeUrl(raw: string): string {
    const trimmed = raw.trim()
    if (!trimmed) return trimmed

    const hasScheme = /^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(trimmed)
    return hasScheme ? trimmed : `https://${trimmed}`
  }

  function deriveName(url: string): string {
    try {
      const parsed = new URL(url)
      if (parsed.hostname) {
        return parsed.hostname
      }
      if (parsed.protocol === 'mailto:' && parsed.pathname) {
        return parsed.pathname
      }
      return parsed.href
    } catch {
      return url
    }
  }

  let groups = $derived(programStore.groups)
  let resolvedGroupId = $derived(uiStore.dialogData.groupId || groups[0]?.id || '')

  let selectedGroupId = $state('')
  let url = $state('')
  let name = $state('')
  let launchGroup = $state(0)

  // Sync selectedGroupId when resolvedGroupId changes
  $effect(() => {
    if (!selectedGroupId && resolvedGroupId) {
      selectedGroupId = resolvedGroupId
    }
  })

  function handleSubmit(event: SubmitEvent) {
    event.preventDefault()
    if (!url.trim() || !selectedGroupId) return

    const normalizedUrl = normalizeUrl(url)
    const finalName = name.trim() || deriveName(normalizedUrl)

    programStore.addItem(selectedGroupId, {
      name: finalName,
      path: normalizedUrl,
      icon: 'web',
      workingDir: '',
      shortcutKey: '',
      launchGroup
    })

    uiStore.closeDialog()
  }

  function closeDialog() {
    uiStore.closeDialog()
  }
</script>

<Dialog title="Add URL" onClose={closeDialog} width={420}>
  {#snippet children()}
    <form onsubmit={handleSubmit}>
      {#if groups.length > 1}
        <div class="win31-form-row">
          <label for="url-group">Program Group:</label>
          <select
            id="url-group"
            class="win31-input"
            bind:value={selectedGroupId}
          >
            {#each groups as group (group.id)}
              <option value={group.id}>
                {group.name}
              </option>
            {/each}
          </select>
        </div>
      {/if}

      <div class="win31-form-row">
        <label for="url-input">URL:</label>
        <TextInput
          id="url-input"
          bind:value={url}
          autofocus
          placeholder="https://example.com"
        />
      </div>

      <div class="win31-form-row">
        <label for="url-name">Name:</label>
        <TextInput
          id="url-name"
          bind:value={name}
          placeholder="Optional (defaults to host)"
        />
      </div>

      <div class="win31-form-row">
        <label for="url-launch-group">Launch Group:</label>
        <select
          id="url-launch-group"
          class="win31-input"
          bind:value={launchGroup}
          style="width: 150px;"
        >
          {#each LAUNCH_GROUP_OPTIONS as value (value)}
            <option {value}>
              {formatLaunchGroup(value)}
            </option>
          {/each}
        </select>
      </div>

      <div class="win31-dialog-buttons">
        <Button type="submit" isDefault disabled={!url.trim() || !selectedGroupId}>
          {#snippet children()}OK{/snippet}
        </Button>
        <Button type="button" onclick={closeDialog}>
          {#snippet children()}Cancel{/snippet}
        </Button>
      </div>
    </form>
  {/snippet}
</Dialog>
