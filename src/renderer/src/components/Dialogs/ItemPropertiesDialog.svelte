<script lang="ts">
  import Dialog from './Dialog.svelte'
  import Button from '../Common/Button.svelte'
  import TextInput from '../Common/TextInput.svelte'
  import { uiStore, programStore } from '@/stores'
  import { getIconSrc, BUILTIN_ICONS } from '@/utils/icons'
  import { LAUNCH_GROUP_OPTIONS, formatLaunchGroup } from '@/utils/launchGroups'

  let groups = $derived(programStore.groups)
  let isEditing = $derived(!!uiStore.dialogData.item)
  let existingItem = $derived(uiStore.dialogData.item)

  let resolvedGroupId = $derived(
    uiStore.dialogData.groupId ||
    (existingItem
      ? groups.find((group) => group.items.some((item) => item.id === existingItem.id))?.id
      : groups[0]?.id) ||
    ''
  )

  let selectedGroupId = $state('')
  let name = $state('')
  let path = $state('')
  let workingDir = $state('')
  let shortcutKey = $state('')
  let icon = $state('default')
  let launchGroup = $state(0)
  let showIconPicker = $state(false)

  // Initialize state from existing item
  $effect(() => {
    if (existingItem) {
      name = existingItem.name || ''
      path = existingItem.path || ''
      workingDir = existingItem.workingDir || ''
      shortcutKey = existingItem.shortcutKey || ''
      icon = existingItem.icon || 'default'
      launchGroup = existingItem.launchGroup ?? 0
    }
  })

  // Sync selectedGroupId when resolvedGroupId changes
  $effect(() => {
    if (!selectedGroupId && resolvedGroupId) {
      selectedGroupId = resolvedGroupId
    }
  })

  async function handleBrowsePath() {
    const selectedPath = await window.electronAPI.file.selectExecutable()
    if (selectedPath) {
      path = selectedPath
      // Set name from filename if empty
      if (!name) {
        const fileName = selectedPath.split(/[/\\]/).pop() || ''
        name = fileName.replace(/\.[^/.]+$/, '')
      }
    }
  }

  function handleSubmit(event: SubmitEvent) {
    event.preventDefault()
    if (!name.trim() || !path.trim() || !selectedGroupId) return

    if (isEditing && existingItem) {
      programStore.updateItem(resolvedGroupId, existingItem.id, {
        name: name.trim(),
        path: path.trim(),
        workingDir: workingDir.trim(),
        shortcutKey: shortcutKey.trim(),
        icon,
        launchGroup
      })
      if (resolvedGroupId && selectedGroupId !== resolvedGroupId) {
        programStore.moveItem(resolvedGroupId, selectedGroupId, existingItem.id)
      }
    } else {
      programStore.addItem(selectedGroupId, {
        name: name.trim(),
        path: path.trim(),
        workingDir: workingDir.trim(),
        shortcutKey: shortcutKey.trim(),
        icon,
        launchGroup
      })
    }
    uiStore.closeDialog()
  }

  function handleDelete() {
    if (existingItem && resolvedGroupId) {
      programStore.deleteItem(resolvedGroupId, existingItem.id)
      uiStore.closeDialog()
    }
  }

  function closeDialog() {
    uiStore.closeDialog()
  }
</script>

<Dialog
  title={isEditing ? 'Program Item Properties' : 'New Program Item'}
  onClose={closeDialog}
  width={450}
>
  {#snippet children()}
    <form onsubmit={handleSubmit}>
      {#if groups.length > 1}
        <div class="win31-form-row">
          <label for="item-group">Program Group:</label>
          <select
            id="item-group"
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
        <label for="item-name">Description:</label>
        <TextInput
          id="item-name"
          bind:value={name}
          autofocus
        />
      </div>

      <div class="win31-form-row">
        <label for="item-path">Command Line:</label>
        <TextInput
          id="item-path"
          bind:value={path}
        />
        <Button type="button" onclick={handleBrowsePath}>
          {#snippet children()}Browse...{/snippet}
        </Button>
      </div>

      <div class="win31-form-row">
        <label for="item-workdir">Working Directory:</label>
        <TextInput
          id="item-workdir"
          bind:value={workingDir}
        />
      </div>

      <div class="win31-form-row">
        <label for="item-shortcut">Shortcut Key:</label>
        <TextInput
          id="item-shortcut"
          bind:value={shortcutKey}
          placeholder="e.g., Ctrl+Alt+F"
          style="width: 150px;"
        />
      </div>

      <div class="win31-form-row">
        <label for="item-launch-group">Launch Group:</label>
        <select
          id="item-launch-group"
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

      <div class="win31-form-row">
        <label>Icon:</label>
        <div style="display: flex; align-items: center; gap: 8px; flex: 1;">
          <img
            src={getIconSrc(icon)}
            alt="Icon"
            width="32"
            height="32"
            style="image-rendering: pixelated;"
          />
          <Button type="button" onclick={() => showIconPicker = !showIconPicker}>
            {#snippet children()}{showIconPicker ? 'Hide Icons' : 'Change Icon...'}{/snippet}
          </Button>
        </div>
      </div>

      {#if showIconPicker}
        <div
          style="
            display: grid;
            grid-template-columns: repeat(8, 1fr);
            gap: 4px;
            padding: 8px;
            background: var(--win31-white);
            border: 2px inset var(--bevel-dark);
            margin-bottom: 10px;
            max-height: 150px;
            overflow-y: auto;
          "
        >
          {#each BUILTIN_ICONS as iconOption (iconOption.id)}
            <div
              onclick={() => icon = iconOption.id}
              title={iconOption.name}
              role="button"
              tabindex="0"
              style="
                width: 36px;
                height: 36px;
                display: flex;
                align-items: center;
                justify-content: center;
                cursor: pointer;
                border: {icon === iconOption.id ? '2px solid var(--win31-blue)' : '2px solid transparent'};
                background: {icon === iconOption.id ? 'var(--selection-bg)' : 'transparent'};
              "
            >
              <img
                src={iconOption.icon}
                alt={iconOption.name}
                width="32"
                height="32"
                style="image-rendering: pixelated;"
              />
            </div>
          {/each}
        </div>
      {/if}

      <div class="win31-dialog-buttons">
        <Button
          type="submit"
          isDefault
          disabled={!name.trim() || !path.trim() || !selectedGroupId}
        >
          {#snippet children()}OK{/snippet}
        </Button>
        <Button type="button" onclick={closeDialog}>
          {#snippet children()}Cancel{/snippet}
        </Button>
        {#if isEditing}
          <Button type="button" onclick={handleDelete}>
            {#snippet children()}Delete{/snippet}
          </Button>
        {/if}
      </div>
    </form>
  {/snippet}
</Dialog>
